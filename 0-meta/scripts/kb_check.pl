#!/usr/bin/env perl
# Workbench health check: the Perl twin of kb_check.py, for laptops without Python.
# Perl ships with git on Windows, macOS and Linux. Same checks, same output, same exit code:
# 0-meta/scripts/test-kb-check.sh compares the two on several workbenches. Change both.
#   perl 0-meta/scripts/kb_check.pl [--brief|--report]     (or: sh kb check / sh kb report)
use strict;
use warnings;
use utf8;
use Encode qw(decode);
use File::Basename qw(dirname basename);
use File::Spec;
use File::Find;
use Cwd qw(abs_path);
use Time::Local qw(timelocal);
use File::Glob qw(bsd_glob);
binmode STDOUT, ":encoding(UTF-8)";

my $ROOT = abs_path(dirname(abs_path(__FILE__)) . "/../..");
my $HOME = $ENV{HOME} // $ENV{USERPROFILE} // "";
$HOME =~ s{\\}{/}g;
my %NO_INDEX = map { $_ => 1 } qw(templates scripts inbox notes slack-bot);
my %TEXT_EXT = map { $_ => 1 } qw(.md .yaml .yml .json .py .pl .sh .toml .txt .example .mdc);
my %PATTERN_FILES = map { $_ => 1 } qw(kb_check.py kb_check.pl guard.py guard.pl prompt_guard.py prompt_guard.pl);
my @SECRETS = (
  [ qr/AKIA[0-9A-Z]{16}/, "AWS access key" ],
  [ qr/gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}/, "GitHub token" ],
  [ qr/sk-(ant-)?[A-Za-z0-9_-]{20,}/, "API key" ],
  [ qr/xox[abprs]-[A-Za-z0-9-]{10,}/, "Slack token" ],
  [ qr/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "private key" ],
  [ qr/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/, "JWT" ],
  [ qr/(?i)\b(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*['"]?[^\s'"<>{}\$]{8,}/, "credential assignment" ],
  [ qr/(?i)(postgres(ql)?|mysql|mongodb(\+srv)?|sqlserver|redis|amqp):\/\/[^\s:\/@]+:[^\s@]+@/, "connection string with password" ],
);
my $HIDDEN = qr/[\x{200b}-\x{200f}\x{202a}-\x{202e}\x{2060}-\x{2064}\x{feff}\x{e0000}-\x{e007f}]/;
my $LINK = qr/\[[^\]]*\]\(([^)\s#]+)(#[^)]*)?\)/;

sub readf {
  my $p = shift;
  open(my $h, "<:raw", $p) or return "";
  local $/;
  my $b = <$h> // "";
  close $h;
  return decode("UTF-8", $b);
}
sub lines_of { my $t = shift; my @l = split /\r\n|\n|\r/, $t, -1; pop @l if @l && $l[-1] eq ""; return @l }
sub tokens { (my $t = shift) =~ s/<!--.*?-->//gs; return sprintf("%.0f", length($t) / 4) + 0 }
sub relp {
  my $p = shift;
  return substr($p, length($ROOT) + 1) if index($p, "$ROOT/") == 0;
  return "~/" . substr($p, length($HOME) + 1) if length $HOME && index($p, "$HOME/") == 0;
  return $p;
}
sub parts { my $r = shift; return split m{/}, $r }
sub by_parts { # Python sorts paths by their parts, not by the whole string
  my @a = parts($a); my @b = parts($b);
  for my $i (0 .. ($#a < $#b ? $#a : $#b)) { my $c = $a[$i] cmp $b[$i]; return $c if $c }
  return @a <=> @b;
}
sub suffix { my $n = shift; my $i = rindex($n, "."); return ($i > 0 && $i < length($n) - 1) ? substr($n, $i) : "" }
sub stem { my $n = shift; my $i = rindex($n, "."); return ($i > 0 && $i < length($n) - 1) ? substr($n, 0, $i) : $n }
sub expanduser { my $p = shift; $p =~ s{^~}{$HOME}; return $p }
sub globsorted { my @g = sort by_parts grep { -e } bsd_glob(shift); return @g }
sub today_days { my @t = localtime; return int(timelocal(0, 0, 12, $t[3], $t[4], $t[5]) / 86400) }
sub date_days { my ($y, $m, $d) = split /-/, shift; return int(timelocal(0, 0, 12, $d, $m - 1, $y) / 86400) }

sub config {
  my %cfg = (boot_budget_tokens => 2000, now_max_lines => 40, state_max_lines => 80, stale_days => 14, skill_description_max => 300);
  my $path = "$ROOT/0-meta/kb.yaml";
  if (-e $path) {
    for (lines_of(readf($path))) {
      if (/^(\w+):\s*([^#]*)/) { my ($k, $v) = ($1, $2); $v =~ s/^\s+|\s+$//g; $cfg{$k} = $v }
    }
  }
  return \%cfg;
}

sub imports {
  my ($entry, $seen, $depth) = @_;
  $seen //= []; $depth //= 0;
  return $seen if $depth > 4 || !-f $entry || grep { $_ eq $entry } @$seen;
  push @$seen, $entry;
  (my $text = readf($entry)) =~ s/```.*?```//gs;
  while ($text =~ /^@(\S+)/mg) {
    my $ref = $1;
    my $target = $ref =~ /^~/ ? expanduser($ref) : dirname($entry) . "/$ref";
    my $abs = -e $target ? abs_path($target) : $target;
    imports($abs, $seen, $depth + 1);
  }
  return $seen;
}

my (@FILES, @DIRS);
find({ no_chdir => 1, wanted => sub {
  my $p = $File::Find::name;
  return if $p eq $ROOT;
  my $r = substr($p, length($ROOT) + 1);
  my @pt = parts($r);
  if (grep { $_ eq ".git" || $_ eq "node_modules" || $_ eq "__pycache__" } @pt) { $File::Find::prune = 1 if -d $p; return }
  if (-d $p) { push @DIRS, $p } elsif (-f $p) { push @FILES, $p }
} }, $ROOT);

sub fresh {
  my ($page, $days) = @_;
  return 0 unless -e $page;
  return 0 unless readf($page) =~ /^updated:\s*(\d{4}-\d{2}-\d{2})/m;
  return today_days() - date_days($1) <= $days;
}

sub linked_repos {
  my @repos;
  for my $card (globsorted("$ROOT/2-work/*/README.md")) {
    next if basename(dirname($card)) =~ /^_/;
    if (readf($card) =~ /^- Repo:\s*`?([^`\s]+)`?/m) { my $p = expanduser($1); push @repos, $p if -d $p }
  }
  return @repos;
}

sub report {
  my $cfg = shift;
  my $days = int($cfg->{stale_days});
  my @repos = linked_repos();
  my $user = "$HOME/.claude";
  my @rows;
  my $profile = "$ROOT/1-me/profile.md";
  my @filled = -e $profile ? grep { /^- / && index($_, "<!--") < 0 } lines_of(readf($profile)) : ();
  push @rows, [ "Identity", @filled >= 3, "profile.md: " . scalar(@filled) . " lines filled in", "/kb-setup" ];
  my @items = grep { basename(dirname($_)) !~ /^_/ } globsorted("$ROOT/2-work/*/state.md");
  my @current = grep { fresh($_, $days) } @items;
  my $now_ok = fresh("$ROOT/NOW.md", $days);
  push @rows, [ "Memory", ($now_ok && @current) ? 1 : 0, "NOW.md " . ($now_ok ? "current" : "stale or undated") . " · " . scalar(@current) . "/" . scalar(@items) . " items current", "kb-capture" ];
  my @ruled = grep { -e "$_/AGENTS.md" } @repos;
  push @rows, [ "Rules", @ruled ? 1 : 0, scalar(@ruled) . " linked repo(s) with AGENTS.md", "/kb-link-repo" ];
  my %own;
  for my $base ("$user/skills", map { "$_/.claude/skills" } @repos) {
    for my $s (globsorted("$base/*/SKILL.md")) { my $n = basename(dirname($s)); $own{$n} = 1 unless $n =~ /^kb-/ }
  }
  push @rows, [ "Skills", %own ? 1 : 0, scalar(keys %own) . " of your own (plus the kb-* skills)", "0-meta/templates/skill/" ];
  my $mcp = "$ROOT/3-toolbox/mcp.md";
  my @reg;
  if (-e $mcp) {
    my @chunks = split /## Register/, readf($mcp), -1;
    my $sec = (split /##/, $chunks[-1], -1)[0] // "";
    @reg = grep { /^\| / && index($_, "<!--") < 0 && !/^\| Server/ && index($_, "---") < 0 } lines_of($sec);
  }
  my @wired = grep { -e "$_/.mcp.json" } @repos;
  push @rows, [ "Reach", (@reg || @wired) ? 1 : 0, scalar(@reg) . " server(s) in mcp.md · " . scalar(@wired) . " repo(s) with .mcp.json", "3-toolbox/mcp.md" ];
  my $settings = "$user/settings.json";
  my $personal = (-e $settings && index(readf($settings), "disableBypassPermissionsMode") >= 0) ? 1 : 0;
  my @guarded = grep { -e "$_/.claude/hooks/guard.py" || -e "$_/.claude/hooks/guard.pl" } @repos;
  push @rows, [ "Guards", ($personal && @guarded) ? 1 : 0, "personal kit " . ($personal ? "on" : "off") . " · " . scalar(@guarded) . " repo(s) guarded", "/kb-link-repo + personal kit" ];
  my @golden = grep { my $s = stem(basename($_)); $s ne "README" && $s !~ /^example/ } map { globsorted("$_/.claude/golden/*.md") } @repos;
  my @reviewer = grep { -e "$_/.claude/agents/reviewer.md" } @repos;
  push @rows, [ "Checks", (@golden || @reviewer) ? 1 : 0, scalar(@golden) . " golden task(s) · reviewer in " . scalar(@reviewer) . " repo(s)", ".claude/golden/ + reviewer agent" ];
  my $score = grep { $_->[1] } @rows;
  print "Your workbench: $score/7 drawers\n\n";
  my $n = 0;
  for my $r (@rows) {
    $n++;
    my $hint = $r->[1] ? "" : "  → $r->[3]";
    printf "  %s %d %-9s %s%s\n", ($r->[1] ? "✓" : "·"), $n, $r->[0], $r->[2], $hint;
  }
  print "\n  No linked repo found yet: add '- Repo: `path`' to a work item card, or run /kb-link-repo.\n" unless @repos;
  return 0;
}

sub main {
  my %arg = map { $_ => 1 } @ARGV;
  my $cfg = config();
  return report($cfg) if $arg{"--report"};
  my $brief = $arg{"--brief"};
  my (@errors, @warnings, @info);

  # boot
  my $boot = imports(abs_path("$ROOT/CLAUDE.md") // "$ROOT/CLAUDE.md");
  $boot = [ "$ROOT/AGENTS.md" ] unless @$boot;
  my $profile = "$ROOT/1-me/profile.md";
  push @$boot, $profile if -e $profile && !grep { $_ eq $profile } @$boot;
  my $cost = 0; $cost += tokens(readf($_)) for @$boot;
  my $budget = int($cfg->{boot_budget_tokens});
  my $line = "Boot cost ~$cost tokens (budget $budget): " . join(", ", map { relp($_) . " ~" . tokens(readf($_)) } @$boot);
  push @{ $cost > $budget ? \@warnings : \@info }, $line;
  my $user_md = "$HOME/.claude/CLAUDE.md";
  if (-e $user_md) {
    my $g = imports(abs_path($user_md));
    my $gcost = 0; $gcost += tokens(readf($_)) for @$g;
    my $msg = "Global boot (every repo, from ~/.claude/CLAUDE.md) ~$gcost tokens";
    push @{ $gcost > $budget ? \@warnings : \@info }, $msg . ($gcost > $budget ? "; trim it, it loads everywhere" : "");
  }

  # indexes
  my %dirs = map { $_ => 1 } (@DIRS, map { dirname($_) } @FILES);
  for my $d (sort by_parts keys %dirs) {
    next if $d eq $ROOT;
    my $r = substr($d, length($ROOT) + 1);
    next if grep { /^\./ || $NO_INDEX{$_} || $_ eq "node_modules" || $_ eq "__pycache__" } parts($r);
    my $readme = "$d/README.md";
    if (!-e $readme) { push @warnings, "$r/ has no README.md index"; next }
    my $text = readf($readme);
    opendir(my $dh, $d) or next;
    my @children = sort grep { $_ ne "." && $_ ne ".." } readdir $dh;
    closedir $dh;
    for my $c (@children) {
      next if $c eq "README.md" || $c eq "__pycache__" || $c =~ /^\./;
      push @warnings, "$r/README.md doesn't list $c" if index($text, $c) < 0 && index($text, stem($c)) < 0;
    }
  }

  # links
  for my $p (sort by_parts @FILES) {
    next unless suffix(basename($p)) eq ".md";
    next if grep { $_ eq "templates" } parts(substr($p, length($ROOT) + 1));
    (my $t = readf($p)) =~ s/```.*?```|`[^`]*`|<!--.*?-->//gs;
    while ($t =~ /$LINK/g) {
      my $target = $1;
      next if $target =~ /^[a-z]+:/ || $target =~ m{^/};
      push @warnings, relp($p) . " links to missing $target" unless -e dirname($p) . "/$target";
    }
  }

  # fresh
  my $stale = int($cfg->{stale_days});
  my @pages = ([ "$ROOT/NOW.md", int($cfg->{now_max_lines}) ], map { [ $_, int($cfg->{state_max_lines}) ] } globsorted("$ROOT/2-work/*/state.md"));
  for my $pg (@pages) {
    my ($page, $limit) = @$pg;
    next unless -e $page;
    my $text = readf($page);
    my $n = () = lines_of($text);
    push @warnings, relp($page) . " is $n lines (limit $limit): move history to log.md, detail to notes/" if $n > $limit;
    if ($text !~ /^updated:\s*(\d{4}-\d{2}-\d{2})/m) { push @warnings, relp($page) . " has no 'updated: YYYY-MM-DD' (/kb-setup, or kb-capture)" }
    elsif (today_days() - date_days($1) > $stale) { push @warnings, relp($page) . " last updated $1: still true? (kb-capture)" }
  }

  # skills
  for my $skill (globsorted("$ROOT/.claude/skills/*/SKILL.md")) {
    my @pp = split /---/, readf($skill), -1;
    my $meta = @pp > 2 ? $pp[1] : "";
    my $folder = basename(dirname($skill));
    my ($name) = $meta =~ /^name:\s*(\S+)/m;
    my ($desc) = $meta =~ /^description:\s*(.+)$/m;
    push @warnings, relp($skill) . ": 'name' must match the folder name '$folder'" if !defined $name || $name ne $folder;
    if (!defined $desc) { push @warnings, relp($skill) . ": no description, so it will never trigger" }
    elsif (length($desc) > int($cfg->{skill_description_max})) { push @warnings, relp($skill) . ": description is " . length($desc) . " chars (max $cfg->{skill_description_max})" }
  }

  # safety
  for my $p (sort by_parts @FILES) {
    my $name = basename($p);
    next unless $TEXT_EXT{ suffix($name) } || $name eq ".env" || $name eq ".mcp.json";
    my $r = substr($p, length($ROOT) + 1);
    my $bucket = (parts($r))[0] eq "inbox" ? \@warnings : \@errors;
    my $n = 0;
    for my $text (lines_of(readf($p))) {
      $n++;
      push @$bucket, "$r:$n contains hidden Unicode (can smuggle instructions to an agent)" if $text =~ $HIDDEN;
      next if $PATTERN_FILES{$name};
      for my $s (@SECRETS) { push @$bucket, "$r:$n looks like a $s->[1]" if $text =~ $s->[0] }
    }
  }

  # setup
  my $pending = index(readf("$ROOT/0-meta/kb.yaml"), "TODO") >= 0;
  if ($pending) {
    push @info, "Setup not finished: 0-meta/kb.yaml has TODO. Type /kb-setup.";
    @warnings = grep { index($_, "NOW.md has no 'updated") != 0 } @warnings;
  }
  my $holes = 0;
  for my $p (@FILES) {
    next unless suffix(basename($p)) eq ".md";
    my $top = (parts(substr($p, length($ROOT) + 1)))[0];
    next unless ($top eq "1-me" || $top eq "2-work") && index($p, "_example") < 0;
    my $t = readf($p);
    $holes++ while $t =~ /<!-- /g;
  }
  push @info, "$holes unfilled placeholders in 1-me/ and 2-work/" if $holes;

  if ($brief) {
    my @problems = ((map { "ERROR $_" } @errors), (map { "warn  $_" } @warnings));
    if ($pending && !@errors) { print "Workbench not set up yet: type /kb-setup in Claude Code.\n"; @problems = () }
    if (@problems) {
      print "Workbench check (run kb-tidy to fix):\n";
      print "  $_\n" for @problems[0 .. ($#problems < 7 ? $#problems : 7)];
      print "  … and " . (@problems - 8) . " more\n" if @problems > 8;
    }
  } else {
    for my $g ([ "ERRORS", \@errors ], [ "WARNINGS", \@warnings ], [ "INFO", \@info ]) {
      next unless @{ $g->[1] };
      print "$g->[0] (" . scalar(@{ $g->[1] }) . ")\n";
      print "  $_\n" for @{ $g->[1] };
    }
    print "OK: no problems found.\n" if !@errors && !@warnings;
  }
  return @errors ? 1 : 0;
}

exit main();
