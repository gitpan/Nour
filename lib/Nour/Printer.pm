# vim: ts=4 sw=4 noexpandtab
package Nour::Printer;
{
  $Nour::Printer::VERSION = '0.01';
}

use Moose;
use namespace::autoclean;

use IO::File;
use Data::Dumper;

BEGIN {
	$| = 1;
	autoflush STDOUT 1;
	autoflush STDERR 1;
}

has _option => (
	is => 'rw'
	, isa => 'HashRef'
	, required => 1
	, lazy => 1
	, default => sub { {} }
);

around BUILDARGS => sub {
	my ( $next, $self, @args, $args ) = @_;

	$args = $self->$next( @args );
	$args->{_option}{ $_ } = delete $args->{ $_ } for keys %{ $args };

	return $args;
};


sub verbose {
	my $self = shift;
	return if $self->_option->{quiet};
	return unless $self->_option->{verbose};
	print STDOUT $self->_prefix . '[verbose] ', join ( "\n[verbose] ", @_ ), "\n";
}

sub debug {
	my $self = shift;
	return if $self->_option->{quiet};
	return unless $self->_option->{debug};
	print STDOUT $self->_prefix . '[debug] ', join ( "\n[debug] ", @_ ), "\n";
}

sub test {
	my $self = shift;
	return if $self->_option->{quiet};
	print STDERR $self->_prefix . '[test] ', join ( "\n[test] ", @_ ), "\n";
}

sub info {
	my $self = shift;
	return if $self->_option->{quiet};
	print STDOUT $self->_prefix . '[info] ', join ( "\n[info] ", @_ ), "\n";
}

sub warn {
	my $self = shift;
	return if $self->_option->{quiet};
	print STDERR $self->_prefix . '[warning] ', join ( "\n[warning] ", @_ ), "\n";
}

sub warning { shift->warn( @_ ) }

sub error {
	my $self = shift;
	return $self->fatal( @_ ) if $self->_option->{debug};
	print STDERR $self->_prefix . '[error] ', join ( "\n[error] ", @_ ), "\n";
}

sub fatal {
	my $self = shift;
	die $self->_prefix . '[fatal] ' . join ( "\n[fatal] ", @_ ) . "\n";
}

sub dump {
	my $self = shift;
	my $forced = 1 if ref $_[-1] eq 'HASH' and $_[-1]->{__forced__}; pop @_ if $forced;
	return if $self->_option->{quiet} and not $forced;
	return unless $forced or not ( $self->_option->{ 'dump-config' } or $self->_option->{ 'dump-option' } ) or $self->_option->{dump} or $self->_option->{dumper};
	print STDERR $self->_prefix . ( ref $_ ? "[dump]\n". Dumper( $_ ) : "[dump] $_\n" ) for @_;
}

sub dumper { shift->dump( @_ ) }

sub _prefix {
	my $self = shift;
	my @s;
	push @s, $$ if $self->_option->{pid};
	push @s, threads->self if threads->can( 'self' ) and $self->_option->{pid};
	if ( $self->_option->{timestamp} ) {
		my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime ( time );
		push @s, sprintf ( "%04d-%02d-%02d %02d:%02d:%02d", 1900 + $year, 1 + $mon, $mday, $hour, $min, $sec );
	}
	@s ? '[' . join ( ' ', @s ) . '] ' : '';
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 NAME

Nour::Printer

=head1 VERSION

version 0.01

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
