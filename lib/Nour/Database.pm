# vim: ts=4 sw=4 noexpandtab
package Nour::Database;
{
  $Nour::Database::VERSION = '0.01';
}

use Moose;
use namespace::autoclean;
use DBI;
use DBIx::Simple;
use Carp;
use feature ':5.10';

with 'Nour::Base';

has _option => (
	is => 'rw'
	, isa => 'HashRef'
	, default => sub { {} }
);

has _config => (
	is => 'rw'
	, isa => 'Nour::Config'
	, handles => {
		  config => 'config'
		, merge_config => 'merge'
		, write_config => 'write'
	}
	, lazy => 1
	, required => 1
	, default => sub {
		my $self = shift;
		my $opts = $self->_option;
		my $conf = $opts if keys %{ $opts };
		require Nour::Config;
		 return new Nour::Config ( -conf => $conf ) if $conf;
		 return new Nour::Config ( -base => 'config/database' );
	}
);

has _stored_handle => (
	is => 'rw'
	, isa => 'HashRef'
	, default => sub { {} }
);

has default_db => (
	is => 'rw'
	, isa => 'Str'
	, default => sub {
		my $self = shift;
		my $conf = $self->config;

		return $conf->{default}
			if exists $conf->{default}
				and not ref $conf->{default}
				and exists $conf->{ $conf->{default} }
				and ref $conf->{ $conf->{default} } eq 'HASH';
		return '';
	}
);

has current_db => (
	is => 'rw'
	, isa => 'Str'
	, default => sub {
		my $self = shift;
		return ( $self->default_db or '' );
	}
);

around BUILDARGS => sub {
	my ( $next, $self, @args, $args ) = @_;

	$args = $self->$next( @args );
	$args->{_option}{ $_ } = delete $args->{ $_ } for keys %{ $args };

	return $args;
};

around BUILD => sub {
	my ( $next, $self, @args, $prev ) = @_;

	$prev = $self->$next( @args );

	my $conf = $self->config;

	my %fallback = %{ $conf->{fallback} }
		if exists $conf->{fallback} and ref $conf->{fallback} eq 'HASH';

	for my $alias ( grep { $_ ne 'fallback' and $_ ne 'default' and ref $conf->{ $_ } eq 'HASH' } keys %{ $conf } ) {
		$conf->{ $alias }->{__override} = delete $conf->{ $alias };

		$self->merge_config( $conf->{ $alias }, \%fallback );
		$self->merge_config( $conf->{ $alias }, delete $conf->{ $alias }->{__override} );

		my %conf = %{ delete $conf->{ $alias } };

		$conf->{ $alias }->{conf} = \%conf;
		$conf->{ $alias }->{args} = [
			  $conf{dsn}
			, $conf{username}
			, $conf{password}
			, $conf{option} ? $conf{option} : {}
		];
	}

	return $prev;
};

after BUILD => sub {
	my ( $self, @args ) = @_;

	$self->switch_to( $self->default_db );
};

sub _current_handle {
	my $self = shift;

	my $db = $self->current_db;
	my $dbh = $self->_stored_handle->{ $db };

	return $dbh;
}

sub switch_to {
	my ( $self, $db ) = @_;

	my $conf = $self->config;

	do {
		carp "no such database '$db'";
		return;
	} unless $conf->{ $db };

	do {
		my $dbh;

		eval {
			$dbh = DBI->connect( @{ $conf->{ $db }{args} } );
		};

		croak "problem connecting to database $db: ", $@ if $@ or not $dbh;
		$self->_stored_handle->{ $db } = new DBIx::Simple ( $dbh );
	} unless $self->_stored_handle->{ $db };

	$self->current_db( $db );

	return $self->_stored_handle->{ $db };
}


sub tx {
	my ( $self, $code ) = @_;
	return unless ref $code eq 'CODE';

	my $orig = $self->_current_handle->dbh;
	my $clone = $orig->clone;
	   $clone->{AutoCommit} = 0;

	my $dbh = new DBIx::Simple ( $clone );

	if ( $code->( $dbh ) ) {
		$dbh->commit;
		# hmm, I don't know why but if the original handle has AutoCommit off it doesn't see new records created by
		# the cloned handle even after the cloned handle has committed. For this reason, I'm including this line:
		$self->_current_handle->commit unless $self->_current_handle->dbh->{AutoCommit};
	}
	else {
		$dbh->rollback;
	}

	$dbh->disconnect;
}

sub insert {
	my ( $self, $rel, $rec ) = ( shift, shift, shift );

	my %opts = ref $_[-1] eq 'HASH' ? %{ $_[-1] } : @_;
	my @vals = map { $rec->{ $_ } } sort keys %{ $rec };
	my $cols = join ', ', sort keys %{ $rec };
	my $hold = join ', ', map { '?' } sort keys %{ $rec };
	my $crud = $opts{replace} ? 'replace' : $opts{ignore} ? 'insert ignore' : 'insert';
	my $erel = $rel =~ /^`.*`$/ ? $rel : "`$rel`";
	my ( $sql, @bind ) = $self->_current_handle->query( qq|
		$crud into $erel ( $cols ) values ( $hold )
	|, @vals );

	return $self->insert_id( $rel, $rec ) if $opts{id};
}

sub insert_id {
	my ( $self, $rel, $rec ) = @_;

	# wrap with if ( mysql )
	my $db = $self->_current_handle->dbh->{Name};
	   $db =~ s/^database=([^;].*);host.*$/$1/;

	return $self->_current_handle->last_insert_id( qw/information_schema/, $db, $rel, $rel .'_id' );
}

sub update {
	my ( $self, $rel, $rec, $cond ) = @_;
	return unless ref $cond eq 'HASH';
	return $self->_current_handle->update( $rel, $rec, $cond );
}

sub delete {
	my ( $self, $rel, $cond ) = @_;
	return unless ref $cond eq 'HASH';
	return $self->_current_handle->delete( $rel, $cond );
}

sub AUTOLOAD {
	my $self = shift;

	( my $method = $Nour::Database::AUTOLOAD ) =~ s/^.*://;

	my $dbh = $self->_current_handle;

	return $dbh->$method( @_ ) if $dbh and $dbh->can( $method );
	return $dbh->dbh->$method( @_ ) if $dbh->dbh->can( $method );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 NAME

Nour::Database

=head1 VERSION

version 0.01

=head2 tx
	# This code commits:
	$self->tx( sub {
		my $tx = shift;
		# do some inserts/updates
		return 1;
	} );
	# This code doesn't:
	$self->tx( sub {
		my $tx = shift;
		# do some inserts/updates
		return 0; # or die, return pre-maturely, etc.
	} );

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
