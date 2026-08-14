#!/usr/bin/env perl

use v5.36;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojolicious::Commands;

Mojolicious::Commands->start_app('DPDA');
