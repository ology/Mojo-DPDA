package DPDA;

# ABSTRACT: Dimensional Personality Disorder Assessment

use Mojo::Base 'Mojolicious', -signatures;

our $VERSION = 0.0100;

=head1 NAME

DPDA - Dimensional Personality Disorder Assessment

=head1 DESCRIPTION

A C<DPDA> is a web quiz for the assessment of personality disorders,
built with Mojolicious, jQuery, and Bootstrap 5.

=cut

sub startup ($self) {
    $self->moniker('dpda');

    my $config = $self->plugin('Config');

    my $log = Mojo::Log->new(
        path  => $config->{log_path},
        level => $config->{log_level},
    );
    $self->log($log);

    $self->sessions->cookie_name('dpda.session');
    $self->sessions->default_expiration(3600);    # 1 hour is plenty for a quiz

    $self->defaults(layout => 'default');

    my $r = $self->routes;

    $r->get('/')->to('quiz#index')->name('index');
    $r->get('/overview')->to('quiz#overview')->name('overview');
    $r->get('/sample')->to('quiz#sample')->name('sample');
    $r->get('/question')->to('quiz#question')->name('question');
    $r->post('/quiz')->to('quiz#submit')->name('submit_quiz');
    $r->get('/chart')->to('quiz#chart')->name('chart');
}

1;

__END__

=head1 SEE ALSO

L<Mojolicious>

=head1 AUTHOR

Gene Boggs <gene.boggs@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019-2026 by Gene Boggs.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
