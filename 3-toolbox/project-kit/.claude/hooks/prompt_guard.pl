#!/usr/bin/env perl
# UserPromptSubmit guard: the Perl twin of prompt_guard.py, for laptops without Python.
# Stops a prompt that contains a secret, a real IBAN or a Romanian CNP (both checksum-validated).
# "synthetic:" at the start lets test data through. Change both twins (0-meta/scripts/test-hooks.sh).
use strict;
use warnings;
use JSON::PP;
use Encode qw(decode);
use Math::BigInt;
binmode STDERR, ":encoding(UTF-8)";

my @PATTERNS = (
  [ qr/AKIA[0-9A-Z]{16}/, "an AWS access key" ],
  [ qr/gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}/, "a GitHub token" ],
  [ qr/sk-(ant-)?[A-Za-z0-9_-]{20,}/, "an API key" ],
  [ qr/xox[abprs]-[A-Za-z0-9-]{10,}/, "a Slack token" ],
  [ qr/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "a private key" ],
  [ qr/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/, "a JWT" ],
  [ qr/(postgres(ql)?|mysql|mongodb(\+srv)?|sqlserver|redis|amqp):\/\/[^\s:\/@]+:[^\s@]+@/i, "a connection string with a password" ],
  [ qr/(AccountKey|SharedAccessSignature|Password|Pwd)=[^;\s]{8,}/i, "a connection string secret" ],
);

sub valid_iban {
  (my $s = shift) =~ s/ //g;
  return 0 unless length($s) >= 15 && length($s) <= 34;
  my $r = substr($s, 4) . substr($s, 0, 4);
  my $digits = join "", map { /\d/ ? $_ : ord($_) - 55 } split //, $r;
  return Math::BigInt->new($digits)->bmod(97) == 1;
}

sub valid_cnp {
  my $s = shift;
  my @w = split //, "279146358279";
  my $total = 0;
  $total += substr($s, $_, 1) * $w[$_] for 0 .. 11;
  my $check = $total % 11;
  $check = 1 if $check == 10;
  my ($month, $day) = (substr($s, 3, 2), substr($s, 5, 2));
  return $check == substr($s, 12, 1) && $month >= 1 && $month <= 12 && $day >= 1 && $day <= 31;
}

$SIG{__DIE__} = sub { return if $^S; print STDERR "prompt_guard.pl failed ($_[0]): this prompt was NOT checked.\n"; exit 1 };

# JSON::PP rejects a lone surrogate (\ud800) that Python accepts: retry with U+FFFD in its place.
sub parse_json {
  my $s = decode("UTF-8", shift // "");
  my $r = eval { JSON::PP->new->decode($s) };
  return $r if defined $r || !$@;
  $s =~ s/\\u[dD][89abAB][0-9a-fA-F]{2}(?!\\u[dD][c-fC-F])|(?<!\\u[dD][89abAB][0-9a-fA-F]{2})\\u[dD][c-fC-F][0-9a-fA-F]{2}/\\ufffd/g;
  $r = eval { JSON::PP->new->decode($s) };
  die "unreadable\n" unless defined $r || !$@;
  return $r;
}

binmode STDIN, ":raw";
my $input = do { local $/; <STDIN> } // "";
my $event = eval { parse_json($input) };
if ($@) {
  if ($input =~ /^\s*\{/) { print STDERR "Prompt not sent: the prompt guard could not read it (malformed input). Try again.\n"; exit 2 }
  exit 0;
}
exit 0 unless ref $event eq "HASH";
my $prompt = $event->{prompt};
exit 0 unless defined $prompt && !ref $prompt;
exit 0 if $prompt =~ /^[ \t\r\n]*synthetic:/aai;
my @found = map { $_->[1] } grep { $prompt =~ $_->[0] } @PATTERNS;
while ($prompt =~ /\b([A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?)\b/g) { if (valid_iban($1)) { push @found, "a valid IBAN"; last } }
pos($prompt) = undef;
while ($prompt =~ /\b([1-9]\d{12})\b/g) { if (valid_cnp($1)) { push @found, "a Romanian personal numeric code (CNP)"; last } }
if (@found) {
  print STDERR "Prompt not sent: it contains what looks like " . join(", ", @found) . ". "
    . "Remove it, or use synthetic data. If this is test data on purpose, start the prompt with 'synthetic:'. "
    . "If a real secret was pasted anywhere, rotate it.\n";
  exit 2;
}
exit 0;
