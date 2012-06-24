package Catalyst::Action::FromPSGI;
{
  $Catalyst::Action::FromPSGI::VERSION = '0.001000';
}

# ABSTRACT: Use a Plack app as a Catalyst action

use strict;
use warnings;
use base 'Catalyst::Action';
use HTTP::Message::PSGI qw(res_from_psgi);
use Plack::App::URLMap;

sub nest_app {
   my ($self, $c, $app) = @_;

   my $nest = Plack::App::URLMap->new;

   my $path = '/' . $c->request->path;
   my $rest = join '/', @{$c->request->arguments};
   $path =~ s/\Q$rest\E$//;
   $nest->map( $path => $app );

   return $nest
}

sub snort_plack_response {
   my ($self, $c, $r) = @_;

   $c->res->status($r->code);
   $c->res->body($r->content);
   $c->res->headers($r->headers);
}

sub execute {
   my ($self, $controller, $c, @rest) = @_;

   my $app = $self->code->($controller, $c, @rest);
   my $nest = $self->nest_app($c, $app);
   my $res = res_from_psgi($nest->($c->req->env));
   $self->snort_plack_response($c, $res);

   return;
}

1;


__END__
=pod

=head1 NAME

Catalyst::Action::FromPSGI - Use a Plack app as a Catalyst action

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

First, you have a plack app you wrote and want to use:

 package MyApp::WS::App;

 use Web::Simple;

 has name => (
    is => 'ro',
    required => 1,
 );

 sub dispatch_request {
    sub (/hi) {
       [ 200,
          [ 'Content-type' => 'text/plain' ],
          [ 'Hello ' . $_[0]->name ]
       ]
    },
 }

 1;

Now you want to reuse this app in a Catalyst action:

 package MyApp::Controller::HelloName;

 use base 'Catalyst::Controller';

 sub say_hi :Path('/say_hi_to') ActionClass('FromPlack') {
   my ($self, $c, $name, @args) = @_;

   MyApp::WS::App->new(name => $name)->to_psgi_app
 }

 1;

The above would yield C<'Hello fREW'> for the request to
C</say_hi_to/fREW/hi>.

Of course the above example is contrived, but keep in mind this will work for
any of the myriad Plack apps out there.

=head1 DESCRIPTION

C<Catalyst::Action::FromPlack> gives you a handy way to mount Plack apps
under Catalyst actions.

Note that because Catalyst is in control of the dispatch cycle any limitations
you place on it will be placed on the Plack app as well.  So for example:

 sub foo : Path('/foo') Args(1) ActionClass('FromPlack') { ... }

will never run the Plack app if the url is C</foo/bar/baz> because the
Catalyst dispatcher won't even match for more than one argument.  For this
reason I recommend leaving C<Args> unspecified for C<FromPlack> actions.

I actually made this because I'm interested in using L<Web::Machine> instead
of L<Catalyst::Action::REST> and possibly even replacing my chaining code
with L<Web::Simple> based dispatching.

=head1 THANKS

Matt S. Trout - for pioneering the actual guts of this code.  Stevan Little -
for porting L<Web::Machine>, my motivation for making this.

=head1 AUTHOR

Arthur Axel "fREW" Schmidt <frioux+cpan@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Arthur Axel "fREW" Schmidt.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

