#!/usr/bin/env perl
# Perl twin of run.py, for laptops without Python (Perl comes with git). Same tasks, same
# output. Run it as  sh .claude/golden/run.sh [name] [--list] [--keep]: that picks Python if
# this laptop has it, this file otherwise. Change one twin, change the other.
use strict;
use warnings;
use JSON::PP;
use File::Basename qw(dirname basename);
use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use Cwd qw(abs_path);
use Encode qw(decode encode);

binmode STDOUT, ':encoding(UTF-8)';
$| = 1;
my $HERE = dirname(abs_path($0));
my $DEFAULT_TOOLS = 'Read,Edit,Write,Grep,Glob';
my $TIMEOUT = 900;    # seconds per task (needs `timeout` on PATH: Git Bash and Linux have it; on a Mac, coreutils)
my $CACHE = qr{(^|/)(__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|node_modules|\.tox|\.venv)(/|$)|\.py[co]$};

sub slurp { my ($p) = @_; open(my $h, '<:raw', $p) or return ''; local $/; my $t = <$h>; close $h; decode('UTF-8', $t) }
sub q_ { my ($s) = @_; $s =~ s/'/'\\''/g; "'$s'" }

sub parse {
    my ($path) = @_;
    my $text = slurp($path); $text =~ s/\r\n/\n/g;
    my (%meta, $body); $body = $text;
    if ($text =~ /\A---\n(.*?)\n---\n(.*)\z/s) {
        my $head = $1; $body = $2;
        for my $line (split /\n/, $head) {
            my ($k, $v) = split /:/, $line, 2; $v //= '';
            $k =~ s/^\s+|\s+$//g; next unless length $k;
            $v =~ s/\s+#.*$//; $v =~ s/^\s+|\s+$//g; $meta{$k} = $v;
        }
    }
    $body =~ s/<!--.*?-->//gs; $body =~ s/^\s+|\s+$//g;
    return (\%meta, $body);
}

# Run a check (any shell line: `FOO=1 npm test`, `cd api && make test`) in a directory, as run.py's
# shell=True does; returns (exit code, combined output). 124 = it timed out.
sub sh_in {
    my ($cwd, $cmd, $timeout) = @_;
    my $t = $timeout && system('command -v timeout >/dev/null 2>&1') == 0 ? "timeout $timeout " : '';
    my $out = `cd @{[q_($cwd)]} && ${t}sh -c @{[q_(encode('UTF-8', $cmd))]} 2>&1`;
    return ($? >> 8, decode('UTF-8', $out // ''));
}

# Ctrl-C on a 15-minute run must not leave a worktree behind (run.py's `finally` does the same).
my ($LIVE_ROOT, $LIVE_WORK);
for my $sig (qw(INT TERM)) {
    $SIG{$sig} = sub {
        sh_out($LIVE_ROOT, "git worktree remove --force " . q_($LIVE_WORK)) if $LIVE_WORK;
        print "\n  stopped\n"; exit 130;
    };
}
sub sh_out { my ($cwd, $cmd) = @_; my $o = `cd @{[q_($cwd)]} && $cmd 2>/dev/null`; return decode('UTF-8', $o // '') }

sub glob_re { my ($g) = @_; my $r = quotemeta $g; $r =~ s/\\\*/.*/g; $r =~ s/\\\?/./g; qr/\A$r\z/s }

sub run_task {
    my ($root, $path, $keep) = @_;
    my ($meta, $prompt) = parse($path);
    (my $name = basename($path)) =~ s/\.md$//i;
    return { name => $name, ok => 0, why => "task needs a 'check:' and a prompt", cost => 0, turns => 0, secs => 0 }
        unless $meta->{check} && length $prompt;
    my $work = tempdir("golden-$name-XXXXXX", TMPDIR => 1); remove_tree($work);
    sh_out($root, "git worktree add --detach --quiet " . q_($work) . " HEAD");
    ($LIVE_ROOT, $LIVE_WORK) = ($root, $work) unless $keep;
    my $started = time;
    my %r = (name => $name, ok => 0, why => '', cost => 0, turns => 0);
    my $cmd = join ' ', 'claude', '-p', q_(encode('UTF-8', $prompt)), '--output-format', 'json', '--permission-mode', 'acceptEdits',
        '--max-turns', q_($meta->{max_turns} // '15'), '--allowedTools', q_($meta->{tools} // $DEFAULT_TOOLS);
    my $t = system('command -v timeout >/dev/null 2>&1') == 0 ? "timeout $TIMEOUT " : '';
    my $stdout = decode('UTF-8', `cd @{[q_($work)]} && $t$cmd 2>/dev/null` // '');
    my $code = $? >> 8;
    if ($code == 124) {
        $r{why} = "timed out after ${TIMEOUT}s";
    } else {
        my $out = eval { decode_json(encode('UTF-8', $stdout)) }; $out = {} unless ref $out eq 'HASH';
        if (open(my $h, '>:encoding(UTF-8)', "$work/.golden-output.txt")) { print $h ($out->{result} // ''); close $h }
        $r{cost} = 0 + ($out->{total_cost_usd} || 0);
        $r{turns} = int($out->{num_turns} || 0);
        my $sub = $out->{subtype};
        $r{why} = 'agent stopped: ' . ($sub // 'no output') if $out->{is_error} || (defined $sub && $sub ne 'success');
        my @changed = map { my $f = substr($_, 3); $f =~ s/^\s+|\s+$//g; $f }
            grep { !/\.golden-output\.txt$/ } split /\n/, sh_out($work, 'git status --porcelain');
        @changed = grep { !/$CACHE/ } @changed;    # test runs leave caches: not an edit
        my @protected = grep { length } map { s/^\s+|\s+$//gr } split /,/, ($meta->{protect} // '');
        my @touched = grep { my $f = $_; grep { $f =~ glob_re($_) } @protected } @changed;
        if (@touched) {
            $r{why} = 'edited protected file(s): ' . join(', ', @touched[0 .. ($#touched < 2 ? $#touched : 2)]);
        } elsif (!$r{why}) {
            my ($rc, $all) = sh_in($work, $meta->{check}, $TIMEOUT);
            $r{ok} = $rc == 0 ? 1 : 0;
            if ($rc == 124) {
                $r{why} = "timed out after ${TIMEOUT}s";
            } elsif (!$r{ok}) {
                my @lines = split /\n/, ($all =~ s/^\s+|\s+$//gr);
                $r{why} = 'check failed: ' . substr(@lines ? $lines[-1] : '(no output)', 0, 80);
            }
        }
    }
    $r{secs} = time - $started;
    if ($keep) { $r{why} = "$r{why} (kept: $work)" =~ s/^\s+//r }
    else { sh_out($root, "git worktree remove --force " . q_($work)); $LIVE_WORK = undef }
    return \%r;
}

sub main {
    my @args = grep { !/^--/ } @ARGV;
    my $keep = grep { $_ eq '--keep' } @ARGV;
    my $listing = grep { $_ eq '--list' } @ARGV;
    my $root = sh_out($HERE, 'git rev-parse --show-toplevel'); $root =~ s/\s+$//; $root = '.' unless length $root;
    opendir(my $d, $HERE) or die; my @tasks = sort map { "$HERE/$_" } grep { /\.md$/ && lc($_) ne 'readme.md' } readdir $d; closedir $d;
    if (@args) { @tasks = grep { my $s = basename($_) =~ s/\.md$//r; grep { index($s, $_) >= 0 } @args } @tasks }
    if (!@tasks) { print "No golden tasks yet. Copy .claude/golden/example.md and make it real.\n"; return 1 }
    if ($listing) {
        for my $t (@tasks) { my ($m) = parse($t); printf "  %-28s check: %s\n", basename($t) =~ s/\.md$//r, $m->{check} // '?' }
        return 0;
    }
    print "Note: uncommitted changes are NOT in the runs. Tasks run against HEAD.\n\n"
        if sh_out($root, 'git status --porcelain') =~ /\S/;
    my @results;
    for my $t (@tasks) { printf "  \x{2026} %s\n", basename($t) =~ s/\.md$//r; push @results, run_task($root, $t, $keep) }
    my $passed = grep { $_->{ok} } @results;
    my $cost = 0; $cost += $_->{cost} for @results;
    printf "\n  %-28s %-6s %5s %7s %6s\n", 'task', 'result', 'turns', 'cost', 'time';
    for my $r (@results) {
        printf "  %-28s %-6s %5d %7s %5ds  %s\n", $r->{name}, $r->{ok} ? 'pass' : 'FAIL', $r->{turns}, sprintf('$%.2f', $r->{cost}), $r->{secs}, $r->{why};
    }
    my $per = $passed ? sprintf(" \x{b7} \$%.2f per pass", $cost / $passed) : '';
    printf "\n  %d/%d passed \x{b7} \$%.2f total%s\n", $passed, scalar @results, $cost, $per;
    return $passed == @results ? 0 : 1;
}

exit main();
