requires 'perl', '5.036';

requires 'Mojolicious', '9.34';
requires 'GD::Graph', '1.54';
requires 'Statistics::Frequency';

on 'test' => sub {
    requires 'Test2::V0';
};
