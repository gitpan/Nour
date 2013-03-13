# vim: ts=4 sw=4 noexpandtab
package Nour::Config;
{
  $Nour::Config::VERSION = '0.01';
}

use Moose;
use namespace::autoclean;
use YAML qw/LoadFile DumpFile/;
use File::Find;
use Data::Dumper; # for debug
use feature ':5.10';

with 'Nour::Base';

has _config => (
	is => 'rw'
	, isa => 'HashRef'
	, required => 1
	, lazy => 1
	, default => sub { {} }
);

has _path => (
	is => 'rw'
	, isa => 'HashRef'
);

around BUILDARGS => sub {
	my ( $next, $self, @args, $args ) = @_;

	$args = $self->$next( @args );
	$args->{_config} = delete $args->{ '-conf' } if defined $args->{ '-conf' };
	$args->{_path}{ $_ } = delete $args->{ $_ } for keys %{ $args };

	return $args;
};

around BUILD => sub {
	my ( $next, $self, @args ) = @_;

	# Get config directory.
	my %path;
	for my $name ( keys %{ $self->_path } ) {
		my $path = $self->_path->{ $name };

		if ( $path =~ /^\// and -d $path ) {
			$path{ $name } = $path;
		}
		elsif ( -d $self->path( $path ) ) {
			$path{ $name } = $self->path( $path );
		}
		else {
			for my $sub ( qw/config conf cfg/ ) {
				if ( -d $self->path( $sub, $path ) ) {
					$path{ $name } = $self->path( $sub, $path );
					last;
				}
			}
		}
	};
	return $self->$next( @args ) unless %path;

	my $conf = {};
	if ( my $path = $path{ '-base' } ) {
		finddepth( sub {
			my $name = $File::Find::name;
			if ( $name =~ qr/\w+\.yml$/ ) {
				my ( $key, $val );
				$val = $name;
				$val =~ s/\/\w+\.yml$//;
				$key = $val;
				$key =~ s/^\Q$path\E\/?//;
				my @key = split /\//, $key;
				$path{ $key } = $val if $key and not $path{ $key } and $key[ -1 ] ne 'private';
			}
		}, $path );
	}

	# Get config files and embedded configuration.
	for my $name ( keys %path ) {
		my @name = split /\//, $name;
		my $path = $path{ $name };
		my $conf = $conf;
		for my $name ( @name ) {
			next if $name eq '-base';
			$conf = $conf->{ $name } ||= {};
		}

		$self->build( conf => $conf, path => $path, name => $name );
	}

	$self->config( $conf );

	return $self->$next( @args );
};

sub config {
	my $self = shift;
	my $args = scalar @_;

	if ( $args ) {
		return $self->_config->{ $_[0] } if $args == 1 and not ref $_[0];

		my %config = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

		for my $key ( keys %config ) {
			$self->_config->{ $key } = $config{ $key };
		}
	}

	return $self->_config;
}

sub merge {
	my $self = shift;
	my ( $ref_1, $ref_2 ) = @_;
	for my $key ( keys %{ $ref_2 } ) {
		if ( defined $ref_1->{ $key } ) {
			if ( ref $ref_1->{ $key } eq 'HASH' and ref $ref_2->{ $key } eq 'HASH' ) {
				$self->merge( $ref_1->{ $key }, $ref_2->{ $key } );
			}
			else {
				$ref_1->{ $key } = $ref_2->{ $key };
			}
		}
		else {
			if ( ref $ref_2->{ $key } eq 'HASH' ) {
				my %ref_2_key = %{ $ref_2->{ $key } };
				$ref_1->{ $key } = \%ref_2_key;
			}
			else {
				$ref_1->{ $key } = $ref_2->{ $key };
			}
		}
	}
}

sub build {
	my ( $self, %args ) = @_;
	my ( %file, %conf );

	opendir my $dh, $args{path} or die "Couldn't open directory '$args{path}': $!";
	push @{ $file{public} }, map { "$args{path}/$_" } grep {
		-e "$args{path}/$_" and $_ !~ /^\./ and $_ =~ /\.yml$/
	} readdir $dh;
	closedir $dh;

	# Private sub-dir i.e. "./config/private" for sensitive i.e. .gitignore'd config.
	if ( -d "$args{path}/private" ) {
		my $path = "$args{path}/private";
		opendir my $dh, $path or die "Couldn't open directory '$path': $!";
		push @{ $file{private} }, map { "$path/$_" } grep {
			-e "$path/$_" and $_ !~ /^\./ and $_ =~ /\.yml$/
		} readdir $dh;
		closedir $dh;
	}

	for my $file ( @{ $file{public} } ) {
		my ( $name ) = ( split /\//, $file )[ -1 ] =~ /^(.*)\.yml$/;
		my $conf = LoadFile $file;

		if ( $name eq 'config' or $name eq 'base' ) {
			$conf{public}{ $_ } = $conf->{ $_ } for keys %{ $conf };
		}
		else {
			if ( exists $conf->{ $name } and scalar keys %{ $conf } == 1 ) {
				$conf{public}{ $name } = $conf->{ $name };
			}
			else {
				$conf{public}{ $name }->{ $_ } = $conf->{ $_ } for keys %{ $conf };
			}
		}
	}

	for my $file ( @{ $file{private} } ) {
		my ( $name ) = ( split /\//, $file )[ -1 ] =~ /^(.*)\.yml$/;
		my $conf = LoadFile $file;

		if ( $name eq 'config' or $name eq 'base' ) {
			$conf{private}{ $_ } = $conf->{ $_ } for keys %{ $conf };
		}
		else {
			if ( exists $conf->{ $name } and scalar keys %{ $conf } == 1 ) {
				$conf{private}{ $name } = $conf->{ $name };
			}
			else {
				$conf{private}{ $name }->{ $_ } = $conf->{ $_ } for keys %{ $conf };
			}
		}
	}

	# "Private" config overrides "public."
	$conf{merged} = {};

	$self->merge( $conf{merged}, $conf{public} )  if exists $conf{public};
	$self->merge( $conf{merged}, $conf{private} ) if exists $conf{private};

	$self->merge( $args{conf}, $conf{merged} );
}

sub write {
	my ( $self, $path, $data ) = @_;
	my ( @path, $mkdir );

	$path = $self->path( $path );
	@path = split /\//, $path;
	pop @path;
	$mkdir = join '/', @path;

	system( qw/mkdir -p/, $mkdir );
	system( qw/cp/, $path, "$path.save" ) if -e $path and -s $path;

	DumpFile( $path, $data );
}

__PACKAGE__->meta->make_immutable;

# ABSTRACT: A really confusing but useful package I wrote
# to bootstrap script/application configuration.

1;

__END__

=pod

=head1 NAME

Nour::Config - A really confusing but useful package I wrote

=head1 VERSION

version 0.01

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
