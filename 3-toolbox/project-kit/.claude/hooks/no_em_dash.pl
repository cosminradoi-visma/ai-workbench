#!/usr/bin/env perl
# PostToolUse house-style hook: the Perl twin of no_em_dash.py, for laptops without Python.
# Checks only the text the agent just wrote, only in prose files; exit 2 sends the lines back.
# Change both twins (0-meta/scripts/test-hooks.sh checks they agree).
use strict;
use warnings;
use JSON::PP;
use Encode qw(decode);
binmode STDERR, ":encoding(UTF-8)";

my $PROSE = qr/\.(md|mdx|txt|rst|adoc|html?)$/i;
my @BANNED = ( [ "\x{2014}", "em-dash (\x{2014})", "use a colon, a comma, or two sentences" ] );

binmode STDIN, ":raw";
my $raw = decode("UTF-8", do { local $/; <STDIN> } // "");
my $event = eval { JSON::PP->new->decode($raw) };
# JSON::PP rejects a lone surrogate (\ud800) that Python accepts: retry with U+FFFD in its place.
if (!defined $event) {
  $raw =~ s/\\u[dD][89abAB][0-9a-fA-F]{2}(?!\\u[dD][c-fC-F])|(?<!\\u[dD][89abAB][0-9a-fA-F]{2})\\u[dD][c-fC-F][0-9a-fA-F]{2}/\\ufffd/g;
  $event = eval { JSON::PP->new->decode($raw) };
}
exit 0 unless ref $event eq "HASH";
my $args = ref $event->{tool_input} eq "HASH" ? $event->{tool_input} : {};
my $path = $args->{file_path} // "";
exit 0 unless $path =~ $PROSE;
my $tool = $event->{tool_name} // "";
my $text = $tool eq "Write" ? ($args->{content} // "")
         : $tool eq "Edit" ? ($args->{new_string} // "")
         : $tool eq "MultiEdit" ? join("\n", map { $_->{new_string} // "" } @{ $args->{edits} || [] })
         : "";
my @problems;
for my $b (@BANNED) {
  my ($needle, $name, $fix) = @$b;
  my @lines = map { s/^\s+|\s+$//gr } grep { index($_, $needle) >= 0 } split /\n/, $text;
  next unless @lines;
  my $shown = join "\n", map { "    " . substr($_, 0, 140) } @lines[0 .. ($#lines < 4 ? $#lines : 4)];
  push @problems, "$name in $path, $fix:\n$shown";
}
if (@problems) { print STDERR "House style: rewrite these lines.\n" . join("\n", @problems) . "\n"; exit 2 }
exit 0;
