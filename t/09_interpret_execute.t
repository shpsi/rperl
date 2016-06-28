#!/usr/bin/perl  ## no critic qw(ProhibitExcessMainComplexity)  # SYSTEM SPECIAL 4: allow complex code outside subroutines, must be on line 1

# suppress 'WEXRP00: Found multiple rperl executables' due to blib/ & pre-existing installation(s),
# also 'WARNING WCOCODE00, COMPILER, FIND DEPENDENCIES: Failed to eval-use package' due to RPerl/Test/*/*Bad*.pm & RPerl/Test/*/*bad*.pl
BEGIN { $ENV{RPERL_WARNINGS} = 0; }

# [[[ HEADER ]]]
use strict;
use warnings;
use RPerl::AfterSubclass;
our $VERSION = 0.002_100;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireBriefOpen)  # USER DEFAULT 5: allow open() in perltidy-expanded code
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils
## no critic qw(ProhibitDeepNests)  # SYSTEM SPECIAL 7: allow deeply-nested code

# [[[ INCLUDES ]]]
use RPerl::Test;
use RPerl::Parser;
use RPerl::Generator;
use RPerl::Compiler;
use Test::More;
use File::Find qw(find);
use IPC::Open3;
use IO::Select;

# [[[ OPERATIONS ]]]

my $test_files = {};    # string_hashref
find(
    sub {
        my $file = $File::Find::name;

        #        RPerl::diag('in 09_interpret_execute.t, have $file = ' . $file . "\n");

#        if ( $file !~ m/.*OperatorVoid01NamedVoid.*[.]p[ml]$/xms ) { # TEMP DEBUGGING, ONLY FIND OperatorVoid01NamedVoid*/*.pm & *.pl
        if ( $file !~ m/.pl$/xms ) {
            return;
        }

        if ( ( $file =~ m/Good/ms ) or ( $file =~ m/good/ms ) ) {

            # NEED FIX: remove use of $_ magic variable
            open my filehandleref $FILE_HANDLE, '<', $_
                or croak 'ERROR, Cannot open file ' . $file . ' for reading,' . $OS_ERROR . ', croaking';
            while (<$FILE_HANDLE>) {
                if (m/^\#\s*\<\<\<\s*EXECUTE_SUCCESS\s*\:\s*['"](.*)['"]\s*\>\>\>/xms) {
                    push @{ $test_files->{$file}->{successes} }, $1;
                }
            }
            close $FILE_HANDLE
                or croak 'ERROR, Cannot close file ' . $file . ' after reading,' . $OS_ERROR . ', croaking';
        }
        elsif ( ( $file =~ m/Bad/ms ) or ( $file =~ m/bad/ms ) ) {

            # NEED FIX: remove use of $_ magic variable
            open my filehandleref $FILE_HANDLE, '<', $_
                or croak 'ERROR, Cannot open file ' . $file . ' for reading,' . $OS_ERROR . ', croaking';
            while (<$FILE_HANDLE>) {
                if (m/^\#\s*\<\<\<\s*EXECUTE_ERROR\s*\:\s*['"](.*)['"]\s*\>\>\>/xms) {
                    push @{ $test_files->{$file}->{errors} }, $1;
                }
            }
            close $FILE_HANDLE
                or croak 'ERROR, Cannot close file ' . $file . ' after reading,' . $OS_ERROR . ', croaking';
        }
        else {
            return;
        }
    },
    $RPerl::INCLUDE_PATH . '/RPerl/Test'
);

RPerl::diag( 'in 09_interpret_execute.t, have $test_files = ' . "\n" . Dumper($test_files) . "\n" );

plan tests => scalar keys %{$test_files};

for my $test_file ( sort keys %{$test_files} ) {

    RPerl::diag( 'in 09_interpret_execute.t, have $test_file = ' . $test_file . "\n" );
    my $pid;
    if ( $RPerl::INCLUDE_PATH =~ /blib/ ) {
        my string $test_file_execute_command = $EXECUTABLE_NAME . ' -Mblib=' . $RPerl::INCLUDE_PATH . ' ' . $test_file;
        RPerl::diag( 'in 09_interpret_execute.t, yes blib INCLUDE_PATH, have $test_file_execute_command = ' . $test_file_execute_command . "\n" );
        RPerl::diag( 'in 09_interpret_execute.t, yes blib INCLUDE_PATH, about to call open3()...' . "\n" );
        $pid = open3( 0, \*STDOUT_TEST, \*STDERR_TEST, $test_file_execute_command );    # disable STDIN w/ 0
        RPerl::diag( 'in 09_interpret_execute.t, yes blib INCLUDE_PATH, returned from open3(), have $pid = ' . $pid . "\n" );
    }
    else {
        my string $test_file_execute_command = $EXECUTABLE_NAME . ' -I' . $RPerl::INCLUDE_PATH . ' ' . $test_file;
        RPerl::diag( 'in 09_interpret_execute.t, not blib INCLUDE_PATH, have $test_file_execute_command = ' . $test_file_execute_command . "\n" );
        RPerl::diag( 'in 09_interpret_execute.t, not blib INCLUDE_PATH, about to call open3()...' . "\n" );
        $pid = open3( 0, \*STDOUT_TEST, \*STDERR_TEST, $test_file_execute_command );         # disable STDIN w/ 0
        RPerl::diag( 'in 09_interpret_execute.t, not blib INCLUDE_PATH, returned from open3(), have $pid = ' . $pid . "\n" );
    }

    my $stdout_select;
    my $stderr_select;
    if($OSNAME ne 'MSWin32') {
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32, about to call IO::Select->new()...' . "\n" );
        $stdout_select = IO::Select->new();
        $stderr_select = IO::Select->new();
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32, about to call $stdout_select->add( \*STDOUT_TEST )...' . "\n" );
        $stdout_select->add( \*STDOUT_TEST );
        $stderr_select->add( \*STDERR_TEST );
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32, returned from $stdout_select->add( \*STDOUT_TEST )' . "\n" );
    }

    my $stdout_generated = q{};
    my $stderr_generated = q{};

    # DISABLED: no user input accepted
    #    while (1) {
    #        print "Enter input\n";
    #        chomp( my $stdin_received = <STDIN_TEST> );
    #        print STDIN_TEST "$stdin_received\n";

    #    select( undef, undef, undef, 0.1 ); # allow time for output to be generated; not needed with waitpid() before sysread() calls below

    #        if ( $stdout_select->can_read(0) )  { RPerl::diag('in 09_interpret_execute.t, can read STDOUT_TEST for $test_file = ' . $test_file . "\n"); }
    #        if ( $stderr_select->can_read(0) )  { RPerl::diag('in 09_interpret_execute.t, can read STDERR_TEST for $test_file = ' . $test_file . "\n"); }

    if ( $OSNAME eq 'MSWin32' || $stdout_select->can_read(0) ) {
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stdout_select->can_read(0), about to call sysread STDOUT_TEST...' . "\n" );
        sysread STDOUT_TEST, $stdout_generated, 4096;
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stdout_select->can_read(0), returned from sysread STDOUT_TEST, have $stdout_generated = ' . "\n" . '[BEGIN STDOUT]' . "\n" . $stdout_generated . '[END STDOUT]' . "\n" );
    }
    if ( $OSNAME eq 'MSWin32' || $stderr_select->can_read(0) ) {
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stderr_select->can_read(0), about to call sysread STDERR_TEST...' . "\n" );
        sysread STDERR_TEST, $stderr_generated, 4096;
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stderr_select->can_read(0), returned from sysread STDERR_TEST, have $stderr_generated = ' . "\n" . '[BEGIN STDERR]' . "\n" . $stderr_generated . '[END STDERR]' . "\n" );
    }
 
    RPerl::diag( 'in 09_interpret_execute.t, have $pid = ' . $pid . ', about to call waitpid...' . "\n" );
    waitpid $pid, 0;
    RPerl::diag( 'in 09_interpret_execute.t, have $pid = ' . $pid . ', returned from waitpid...' . "\n" );

    if ( $OSNAME eq 'MSWin32' || $stdout_select->can_read(0) ) {
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stdout_select->can_read(0), about to call sysread STDOUT_TEST...' . "\n" );
        my string $stdout_generated_continued;
        sysread STDOUT_TEST, $stdout_generated_continued, 4096;
        $stdout_generated .= $stdout_generated_continued;
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stdout_select->can_read(0), returned from sysread STDOUT_TEST, have $stdout_generated_continued = ' . "\n" . '[BEGIN STDOUT]' . "\n" . $stdout_generated_continued . '[END STDOUT]' . "\n" );
    }
    if ( $OSNAME eq 'MSWin32' || $stderr_select->can_read(0) ) {
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stderr_select->can_read(0), about to call sysread STDERR_TEST...' . "\n" );
        my string $stderr_generated_continued;
        sysread STDERR_TEST, $stderr_generated_continued, 4096;
        $stderr_generated .= $stderr_generated_continued;
        RPerl::diag( 'in 09_interpret_execute.t, yes MSWin32 or $stderr_select->can_read(0), returned from sysread STDERR_TEST, have $stderr_generated_continued = ' . "\n" . '[BEGIN STDERR]' . "\n" . $stderr_generated_continued . '[END STDERR]' . "\n" );
    }

    # DISABLED: no user input accepted
    #        $stdout_generated = q{};
    #        $stderr_generated = q{};
    #    }

    my $test_exit_status = $CHILD_ERROR >> 8;

    RPerl::diag( 'in 09_interpret_execute.t, have $CHILD_ERROR = ' . $CHILD_ERROR . "\n" );
    RPerl::diag( 'in 09_interpret_execute.t, have $test_exit_status = ' . $test_exit_status . "\n" );

    if ($stdout_generated) { RPerl::diag( "===STDOUT=BEGIN====\n" . $stdout_generated . "===STDOUT=END======\n" ); }
    if ($stderr_generated) { RPerl::diag( "===STDERR=BEGIN====\n" . $stderr_generated . "===STDERR=END======\n" ); }

    my @stdout_generated_lines_array = split( "\n", $stdout_generated );
    my string_arrayref $stdout_generated_lines = \@stdout_generated_lines_array;

    if ( $test_exit_status == 0 ) {    # UNIX process return code 0, success
        if ( ( $test_file =~ m/Good/xms ) or ( $test_file =~ m/good/xms ) ) {
            my $missing_successes = [];
            if ( defined $test_files->{$test_file}->{successes} ) {

                #=DISABLE
                $RPerl::DEBUG   = 0;
                $RPerl::VERBOSE = 0;

                RPerl::diag( 'in 09_interpret_execute.t, before foreach loop, have successes =' . "\n" . Dumper($test_files->{$test_file}->{successes}) . "\n" );

                my string $success = $test_files->{$test_file}->{successes}->[0];

                # match success strings in-order in captured output
            FOREACH_STDOUT_LINE: foreach my string $stdout_generated_line ( @{$stdout_generated_lines} ) {

                    RPerl::diag( 'in 09_interpret_execute.t, top of foreach loop, have $success = ' . $success . "\n" );
                    RPerl::diag( 'in 09_interpret_execute.t, top of foreach loop, have $stdout_generated_line = ' . $stdout_generated_line . "\n" );
                    # each stdout line is only allowed to match one success string
                    if ( $stdout_generated_line =~ /\Q$success\E/xms ) {

                        RPerl::diag( 'in 09_interpret_execute.t, MATCH' . "\n" );
                        shift @{ $test_files->{$test_file}->{successes} };
                        if ( ( scalar @{ $test_files->{$test_file}->{successes} } ) == 0 ) { last FOREACH_STDOUT_LINE; }
                        $success = $test_files->{$test_file}->{successes}->[0];
                    }
                    else { RPerl::diag( 'in 09_interpret_execute.t, NO MATCH' . "\n" ); }
                }
            }
            RPerl::verbose( 'in 09_interpret_execute.t, have missing successes =' . "\n" . Dumper( $test_files->{$test_file}->{successes} ) . "\n" );
            ok( ( ( scalar @{ $test_files->{$test_file}->{successes} } ) == 0 ), 'Program interprets and executes without errors:' . (q{ } x 10) . $test_file );

            #=cut

#DISABLE
                # NEED UPGRADE: below code allows success strings to be matched out-of-order in captured output
                # enable with some appropriate preprocessor keyword
#                foreach my $success (
#                    @{ $test_files->{$test_file}->{successes} } )
#                {
#                    if ( $stdout_generated !~ /\Q$success\E/xms ) {
#                        push @{$missing_successes},
#                            "Success message '$success' expected, but not found";
#                    }
#                }
#            }
#            RPerl::verbose( 'in 09_interpret_execute.t, have $missing_successes =' . "\n" . Dumper($missing_successes) . "\n" );
#            ok( ( ( scalar @{$missing_successes} ) == 0 ), 'Program interprets and executes without errors:' . (q{ } x 10) . $test_file );

        }
        else {
            ok( 0, 'Program interprets and executes with errors:' . (q{ } x 13) . $test_file );
        }
    }
    else {    # UNIX process return code not 0, error
        if ( ( $test_file =~ m/Bad/ms ) or ( $test_file =~ m/bad/ms ) ) {
            my $missing_errors = [];
            if ( defined $test_files->{$test_file}->{errors} ) {
                foreach my $error ( @{ $test_files->{$test_file}->{errors} } ) {
                    if (    ( $stdout_generated !~ /\Q$error\E/xms )
                        and ( $stderr_generated !~ /\Q$error\E/xms ) )
                    {
                        push @{$missing_errors}, "Error message '$error' expected, but not found";
                    }
                }
            }
            ok( ( ( scalar @{$missing_errors} ) == 0 ), 'Program interprets and executes with expected error(s):' . (q{ } x 2) . $test_file );
        }
        else {
            ok( 0, 'Program interprets and executes without errors:' . (q{ } x 10) . $test_file );
        }
    }
}