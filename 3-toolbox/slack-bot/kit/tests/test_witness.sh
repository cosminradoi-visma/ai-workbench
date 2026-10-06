#!/bin/sh
# witnessed(): only real result hits count, never the context messages Slack adds around them.
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh
KIT=$PWD OWNER_ENV=$PWD/tests/fixtures/owner.env
[ -f "$OWNER_ENV" ] || OWNER_ENV=$PWD/owner.env.example
. lib/common.sh 2>/dev/null
F=tests/fixtures/witness-real-format.txt
check() { if witnessed "$2" "$F"; then got=yes; else got=no; fi; [ "$got" = "$3" ] && ok "$1" || bad "$1 (got $got)"; }
check "result hit is witnessed" 1700000000.000100 yes
check "context message is NOT witnessed" 1700000000.000050 no
check "unknown ts is NOT witnessed" 1700000000.999999 no
check "prefix of a ts is NOT witnessed" 1700000000.0001 no
# thread_of(): the thread comes from the result's own permalink, never from context lines.
T=tests/fixtures/witness-thread.txt
tcheck() { got=$(thread_of "$2" "$T"); [ "$got" = "$3" ] && ok "$1" || bad "$1 (got $got)"; }
tcheck "a reply resolves to its thread's first message" 1791178017.633529 1791177914.498279
tcheck "a message outside any thread is its own thread" 1791177999.000002 1791177999.000002
tcheck "a context line's permalink is ignored" 1791177000.000001 1791177000.000001
summary
