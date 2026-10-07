#!/usr/bin/env perl
# Perl twin of statusline.py (model · context used · session cost), for laptops without Python.
# ~/.claude/py picks whichever this laptop has. Copy both to ~/.claude/.
use strict;
use warnings;
use JSON::PP;
binmode STDOUT, ':encoding(UTF-8)';
my $raw = do { local $/; binmode STDIN; <STDIN> } // '';
my $data = eval { JSON::PP->new->utf8->decode($raw) };
exit 0 unless ref $data eq 'HASH';
my $model = (ref $data->{model} eq 'HASH' && defined $data->{model}{display_name}) ? $data->{model}{display_name} : '?';
my $used = ref $data->{context_window} eq 'HASH' ? $data->{context_window}{used_percentage} : undef;
my $cost = ref $data->{cost} eq 'HASH' ? $data->{cost}{total_cost_usd} : undef;
my @parts = ($model);
push @parts, sprintf('ctx %.0f%%%s', $used, $used >= 60 ? '!' : '') if defined $used;
push @parts, sprintf('$%.2f', $cost) if defined $cost;
print join(" \x{b7} ", @parts), "\n";
