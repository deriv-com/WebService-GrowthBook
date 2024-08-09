package WebService::GrowthBook::Util;
use strict;
use warnings;
use Exporter qw(import);
use URI;

our @EXPORT_OK = qw(gbhash in_range get_query_string_override);

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


sub get_query_string_override {
    my ($id, $url, $num_variations) = @_;
    my $uri = URI->new($url);

    # Return undef if there is no query string
    return undef unless $uri->query;

    my %qs = $uri->query_form;

    # Return undef if the id is not in the query string
    return undef unless exists $qs{$id};

    my $variation = $qs{$id};

    # Return undef if the variation is not defined or not a digit
    return undef unless defined $variation && $variation =~ /^\d+$/;

    my $var_id = int($variation);

    # Return undef if the variation id is out of range
    return undef if $var_id < 0 || $var_id >= $num_variations;

    return $var_id;
}

1;
