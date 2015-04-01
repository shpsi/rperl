#!/usr/bin/perl
# [[[ HEADER ]]]
use strict;
use warnings;
use RPerl;
our $VERSION = 0.001_000;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils

# [[[ OPERATIONS ]]]

my number__hash_ref $n_hash = {
    alpha => sin 17 / 23,
    beta  => cos 42 / 1_701,
    gamma => -( sin 21.12 )
};
foreach my string $n_key ( keys %{$n_hash} ) {
    print $n_key, ' => ', $n_hash->{$n_key}, "\n";
}
