package Nour::Base;
{
  $Nour::Base::VERSION = '0.01';
}

use FindBin;
use Moose::Role;
use namespace::autoclean;

has base => (
	is => 'rw'
	, required => 1
	, lazy_build => 1
);

sub _build_base {
	my $self = shift;
	my $base = $FindBin::Bin;

	while ( $base and not -e "$base/lib" ) {
		$base =~ s:/[^/]+/?$::;
	}

	return $base;
};

sub path {
	my ( $self, @path ) = @_;
	my ( $base ) = ( $self->base );

	@path = map { $_ =~ s/^\///; $_ =~ s/\/$//; $_ } @path;
	$base =~ s/\/$//;

	return join '/', $base, @path;
}

sub BUILD {}

1;

__END__

=pod

=head1 NAME

Nour::Base

=head1 VERSION

version 0.01

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
