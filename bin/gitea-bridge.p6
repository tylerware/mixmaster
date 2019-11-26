#!/usr/bin/env perl6

use lib 'lib';

use Config::INI;
use Bridge;

our Str constant REFMAP_PATH = 'refs.ini';

sub MAIN() {
    my Hash %refMap{Str} = Config::INI::parse_file(REFMAP_PATH);

    my Str %headers{Str};

    for lines() {
        parse-headers($_, &%headers);

        unless ($_.trim) {
            last;
        }
    }

    my %json{Str} = parse-json-body(%headers<content-length>);

    my Str $repositoryName = %json<repository><full_name>;

    my Str $repositoryTarget = %json<ref>.subst("refs/heads/", "", :nth(1));

    unless (%refMap{$repositoryName}:exists) {
        send-error-response("Unknown repository");
        exit;
    }

    my Pair @matchedTargets = %refMap{$repositoryName}.pairs.grep: {
        .key.starts-with($repositoryTarget)
    };

    unless (@matchedTargets) {
        send-error-response("Unknown target");
        exit;
    }

    if (@matchedTargets.elems > 1) {
        send-error-response("Multiple matches for this target");
        exit;
    }

    my (Str $matchedTarget, Str $buildCommand) = @matchedTargets.first.kv;

    my $jobFileName = generate-job-file-name();

    spurt "INBOX/{$jobFileName}", qq:to/END/;
    [job]
    scm = git
    repositoryName = $repositoryName
    repositoryUrl = {%json<repository><ssh_url>}
    commit = {%json<after>}
    target = $matchedTarget
    build_command = $buildCommand
    view_url = {%json<compare_url>}
    END

    send-success-response();

    CATCH {
        send-failure-response();
    }
}
