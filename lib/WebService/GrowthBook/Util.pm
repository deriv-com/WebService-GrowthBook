package WebService::GrowthBook::Util;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(gbhash in_range);

sub fnv1a32 {
    my ($str) = @_;
    my $hval = 0x811C9DC5;
    my $prime = 0x01000193;
    my $uint32_max = 2 ** 32;

    foreach my $s (split //, $str) {
        $hval = $hval ^ ord($s);
        $hval = ($hval * $prime) % $uint32_max;
    }

    return $hval;
}
sub gbhash {
    my ($seed, $value, $version) = @_;

    if ($version == 2) {
        my $n = fnv1a32(fnv1a32($seed . $value));
        return ($n % 10000) / 10000;
    }
    if ($version == 1) {
        my $n = fnv1a32($value . $seed);
        return ($n % 1000) / 1000;
    }
    return undef;
}

sub in_range {
    my ($n, $range) = @_;
    return $range->[0] <= $n && $n < $range->[1];
}
1;
