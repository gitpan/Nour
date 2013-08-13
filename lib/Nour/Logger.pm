# vim: ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Logger;
# ABSTRACT: a mixin module for logging, mostly just wraps Mojo::Log

use Moose;
use namespace::autoclean;
use Mojo::Log;
use Data::Dumper qw//;
use Carp;

with 'Nour::Base';


has _logger => (
    is => 'rw'
    , isa => 'Mojo::Log'
    , handles => [ qw/debug error fatal info log warn/ ]
    , default => sub {
        return new Mojo::Log ( level => 'debug' );
    }
);

do {
    my $method = $_;
    around $method => sub {
        my ( $next, $self, @args ) = @_;

        my $dumped = $self->_dumper( pop @args ) if ref $args[ -1 ];
        push @args, $dumped if $dumped;

        return $self->$next( @args );
    };
} for qw/debug error fatal info log warn/;

after fatal => sub {
    my ( $self, @args ) = @_;
    croak @args;
};

sub _dumper {
    my $self = shift;
    return Data::Dumper->new( [ @_ ] )->Indent( 1 )->Sortkeys( 1 )->Terse( 1 )->Dump;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Nour::Logger - a mixin module for logging, mostly just wraps Mojo::Log

=head1 VERSION

version 0.03

=head1 NAME

Nour::Logger

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
