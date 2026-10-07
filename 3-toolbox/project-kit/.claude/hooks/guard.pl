#!/usr/bin/env perl
# PreToolUse guard for Claude Code: the Perl twin of guard.py, for laptops without Python.
# Perl and its JSON module ship with git everywhere (Git for Windows, macOS, Linux), so this
# runs with nothing installed. Same rules, same messages, same exit codes as guard.py:
# 0-meta/scripts/test-hooks.sh runs one matrix against both. Change both, or the test fails.
#
#   DENY (exit 2, reason to the model): secret files, force-push to protected branches,
#        --no-verify, pipe-to-shell, uploading files with curl, destructive SQL, rm -rf on / or ~.
#   ASK  (JSON "ask"): named package installs, sudo, edits to agent config.
#   STOP: `touch .claude/STOP` stops every agent in this repo (and its worktrees).
#   UNATTENDED (.claude/unattended.json): private paths, a post budget on send tools.
# Not a tool call at all: allowed. A tool call it cannot read, an invalid unattended.json,
# or a crash in this file: blocked, with the reason.
use strict;
use warnings;
use JSON::PP;
use Encode qw(decode);
use File::Path qw(make_path);
use B ();
binmode STDERR, ":encoding(UTF-8)";
# A broken guard must not mean "allow". (Plain `die` exits with whatever errno happens to be.)
$SIG{__DIE__} = sub {
  return if $^S;
  print STDERR "Blocked by .claude/hooks/guard.py: the guard itself failed ($_[0]). Ask the user to check .claude/hooks and .claude/unattended.json.\n";
  exit 2;
};

my $SECRET_PATH = q{(\.env(\.(?!example\b|sample\b|template\b|dist\b)[\w-]+)*(?=$|[\s'"/;|&)])}
  . q{|\bid_(rsa|ed25519|ecdsa)\b|\.pem\b|\.pfx\b|\.p12\b|\.key\b}
  . q{|\.aws/credentials|\.kube/config|\.npmrc\b|\.pypirc\b|\.netrc\b|\.claude\.json\b}
  . q{|\bcredentials\.json\b|\bsecrets?\.(json|ya?ml)\b)};
my $READERS = q{\b(cat|less|more|head|tail|bat|nl|strings|xxd|od|base64|grep|egrep|rg|awk|sed|cp|mv|scp|rsync|tar|zip|type|get-content|source)\b};
my $PROTECTED = q{\b(main|master|prod\w*|release\w*)\b};

my @DENY_BASH = (
  [ $READERS . q{[^|;&]*} . $SECRET_PATH, "reading or copying a secrets file" ],
  [ q{\bgit\s+push\b(?=.*(--force(?!-with-lease)|\s-f\b|\s\+))(?=.*} . $PROTECTED . q{)}, "force-push to a protected branch" ],
  [ q{\bgit\s+(commit|push|merge|rebase)\b.*--no-verify\b}, "skipping git hooks with --no-verify" ],
  [ q{\b(curl|wget|iwr|invoke-webrequest)\b[^|]*\|\s*(sudo\s+)?(sh|bash|zsh|python3?|node|iex)\b}, "piping a download into a shell" ],
  [ q{\bcurl\b.*(\s(-d|--data(-binary|-raw|-urlencode)?|-F|--form)\s*['"]?([\w.\[\]-]+=)?@|\s(-T|--upload-file)\s)}, "uploading a local file with curl" ],
  [ q{\b(drop\s+(database|schema|table)|truncate\s+table)\b}, "destructive SQL" ],
  [ q{\brm\s+(-[a-z]*r[a-z]*f?|-[a-z]*f[a-z]*r)[a-z]*\s+(/|~|\$HOME|\.\.)(/\*?)?(\s|$)}, "recursive delete of /, ~ or a parent folder" ],
);
my @ASK_BASH = (
  [ q{\b(npm|pnpm|yarn|bun)\s+(i|install|add)\s+(?!-)[@\w]}, "installs a named package" ],
  [ q{\b(pip3?|uv\s+pip)\s+install\s+(?!-r\b|-e\b|\.)[\w]}, "installs a named package" ],
  [ q{\b(uv|poetry|cargo)\s+add\s+\w|\bgo\s+get\s+\w|\bdotnet\s+add\s+(\S+\s+)?package\b}, "installs a named package" ],
  [ q{(^|[;&|]\s*)sudo\b}, "runs with sudo" ],
);
my $AGENT_CONFIG = q{(^|[\\\\/])(\.claude[\\\\/](settings[\w.]*\.json|hooks[\\\\/]|skills[\\\\/]|agents[\\\\/]|rules[\\\\/]|golden[\\\\/]|unattended\.json$)}
  . q{|\.mcp\.json$|\.cursor[\\\\/]|\.github[\\\\/](workflows|hooks)[\\\\/]|CLAUDE(\.local)?\.md$|AGENTS\.md$)};  # matched with /i: Windows and macOS ignore case

sub deny {
  print STDERR "Blocked by .claude/hooks/guard.py: $_[0]. If it is really needed, ask the user to run it themselves.\n";
  exit 2;
}

sub ask {
  print JSON::PP->new->canonical->ascii->encode({ hookSpecificOutput => {
    hookEventName => "PreToolUse", permissionDecision => "ask", permissionDecisionReason => "guard.py: $_[0]" } }), "\n";
  exit 0;
}

sub slash { my $s = shift // ""; $s =~ s{\\}{/}g; return $s }

sub read_bytes {
  my $f = shift;
  open(my $h, "<:raw", $f) or return undef;
  local $/;
  my $c = <$h>;
  close $h;
  return $c;
}

# UTF-8 always: a byte that will not decode becomes U+FFFD; it must never turn into "allow".
# JSON::PP rejects a lone surrogate (\ud800) that Python accepts: retry with U+FFFD in its place.
sub parse_json {
  my $s = decode("UTF-8", shift // "");
  my $json = JSON::PP->new;
  my $r = eval { $json->decode($s) };
  return $r if defined $r || !$@;
  $s =~ s/\\u[dD][89abAB][0-9a-fA-F]{2}(?!\\u[dD][c-fC-F])|(?<!\\u[dD][89abAB][0-9a-fA-F]{2})\\u[dD][c-fC-F][0-9a-fA-F]{2}/\\ufffd/g;
  $r = eval { $json->decode($s) };
  die "unreadable\n" unless defined $r || !$@;
  return $r;
}

sub text_of { my $v = shift; return "" unless defined $v; return ref $v ? JSON::PP->new->canonical->encode($v) : "$v" }

sub first_path {
  my $args = shift;
  for my $k (qw(file_path notebook_path path)) { my $v = $args->{$k}; return $v if defined $v && !ref $v && length $v }
  return "";
}

# Bots run in git worktrees: STOP and the post budget live in the MAIN checkout.
sub main_checkout {
  my $project = shift;
  my $common = "";
  if (open(my $h, "-|", "git", "-C", $project, "rev-parse", "--path-format=absolute", "--git-common-dir")) {
    local $/; $common = <$h> // ""; close $h;
  }
  $common =~ s/\s+$//;
  return $common =~ m{[\\/]\.git$} ? ($common =~ s{[\\/]\.git$}{}r) : $project;
}

sub home_forms {
  my $raw = shift;
  my @forms = ($raw);
  if ($raw =~ /^~/) {
    for my $home (grep { defined && length } ($ENV{HOME}, $ENV{USERPROFILE})) {
      (my $f = $raw) =~ s{^~}{$home};
      push @forms, $f;
    }
  }
  return map { my $x = slash($_); $x =~ s{/+$}{}; $x } @forms;
}

sub invalid { deny(".claude/unattended.json is invalid ($_[0]). Fix it: this file keeps a bot away from private data") }

sub unattended {
  my ($project, $tool, $args) = @_;
  my $raw = read_bytes("$project/.claude/unattended.json");
  return unless defined $raw;
  my $cfg = eval { parse_json($raw) };
  invalid("not valid JSON") if $@ || !defined $cfg;
  invalid("the top level must be an object") unless ref $cfg eq "HASH";
  my $private = exists $cfg->{private_paths} ? $cfg->{private_paths} : [];
  invalid("private_paths must be a list of strings") unless ref $private eq "ARRAY" && !grep { !defined $_ || ref $_ || JSON::PP::is_bool($_) || !is_string($_) } @$private;
  my $send = $cfg->{send_tools};
  if (defined $send) {
    invalid("send_tools must be a regular expression") if ref $send || !is_string($send);
    invalid("send_tools is not a valid regular expression") unless eval { qr/$send/; 1 };
  }
  my $limit = exists $cfg->{max_sends_per_hour} ? $cfg->{max_sends_per_hour} : 10;
  invalid("max_sends_per_hour must be a whole number") unless defined $limit && !ref $limit && !is_string($limit) && $limit =~ /^\d+$/;

  my $text = lc slash(join " ", map { defined $_ && !ref $_ ? $_ : "" } values %$args);
  my $searched = defined $args->{path} && !ref $args->{path} ? lc slash($args->{path}) : "";
  $searched =~ s{/+$}{};
  for my $raw_path (@$private) {
    for my $form (map { lc } home_forms($raw_path)) {
      # named directly, or searched from a folder above it (Grep ~/workbench)
      deny("$raw_path is private: an unattended agent answers from this repo only")
        if length $form && (index($text, $form) >= 0 || (length($searched) > 1 && index($form, "$searched/") == 0));
    }
  }
  if (defined $send && length $send && $tool =~ /$send/i) {
    my $dir = main_checkout($project) . "/.claude/state";
    my $log = "$dir/sends.log";
    my $now = time;
    my @recent = grep { /^[\d.]+$/ && $now - $_ < 3600 } split /\s+/, (read_bytes($log) // "");
    deny("post budget reached: $limit sends in the last hour") if @recent >= $limit;
    make_path($dir);
    if (open(my $h, ">", $log)) {
      print $h join(" ", @recent, $now);
      close $h;
    }
  }
}

# JSON strings and JSON numbers look alike once decoded: ask JSON::PP's flags which one it was.
sub is_string { my $v = shift; my $b = B::svref_2object(\$v); return ($b->FLAGS & B::SVp_POK()) && !($b->FLAGS & (B::SVp_IOK() | B::SVp_NOK())) }

binmode STDIN, ":raw";
my $input = do { local $/; <STDIN> } // "";
my $event = eval { parse_json($input) };
if ($@) {
  deny("this tool call could not be read (malformed JSON), so it is blocked to be safe") if $input =~ /^\s*\{/;
  exit 0;
}
exit 0 unless ref $event eq "HASH";
my $tool = text_of($event->{tool_name});
my $args = ref $event->{tool_input} eq "HASH" ? $event->{tool_input} : {};
my $project = $ENV{CLAUDE_PROJECT_DIR} || text_of($event->{cwd}) || ".";

for my $p ($project, main_checkout($project)) {
  deny("this repo is stopped (.claude/STOP exists). Remove that file to resume") if -e "$p/.claude/STOP";
}
unattended($project, $tool, $args);

if ($tool eq "Bash") {
  my $cmd = text_of($args->{command});
  # also with Windows backslashes as slashes: cat .aws\credentials
  for my $r (@DENY_BASH) { deny($r->[1]) if $cmd =~ /$r->[0]/i || slash($cmd) =~ /$r->[0]/i }
  for my $r (@ASK_BASH) {
    next unless $cmd =~ /$r->[0]/i;
    my $reason = $r->[1];
    $reason .= ": check it exists, is the one you meant, and isn't brand new (models invent package names)" if $reason =~ /package/;
    ask($reason);
  }
} elsif ($tool =~ /^(Read|Edit|Write|MultiEdit|NotebookEdit|Grep)$/) {
  my $path = first_path($args);
  deny("access to a secrets file ($path)") if slash($path) =~ /${SECRET_PATH}$/i;
  (my $glob = text_of($args->{glob})) =~ s/[*?]//g;
  deny("searching secrets files ($args->{glob})") if $tool eq "Grep" && length $glob && slash($glob) =~ /${SECRET_PATH}$/i;
  ask("edits $path, which changes how agents behave in this repo") if $tool ne "Read" && $tool ne "Grep" && $path =~ /$AGENT_CONFIG/i;
}
exit 0;
