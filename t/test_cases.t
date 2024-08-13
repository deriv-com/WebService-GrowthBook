use strict;
use warnings;
use Test::Warnings;
use Test::More;
use WebService::GrowthBook::Eval qw(eval_condition);
use WebService::GrowthBook::Util qw(gbhash);
use JSON::MaybeUTF8 qw(decode_json_text);
use Path::Tiny;
use FindBin qw($Bin);

my $json_file = path("$Bin/cases.json");
my $test_cases = decode_json_text($json_file->slurp_utf8);

my $eval_condition_cases = $test_cases->{evalCondition};
for my $case (@$eval_condition_cases){
    diag("-" x 80);
    diag(explain($case));
    my ($name, $condition, $attributes, $expected_result) = $case->@*;
    is(eval_condition($attributes, $condition), $expected_result, $name) or exit(0);
}

my $version_compare_cases = $test_cases->{versionCompare};
test_version_compare($version_compare_cases);
test_hash($test_cases->{hash});
ok(1);
done_testing;

sub test_version_compare{
    my $cases = shift;
    for my $op (keys $cases->%*){
        for my $case ($cases->{$op}->@*){
            my ($v1, $v2, $result) = $case->@*;
            my $pv1 = WebService::GrowthBook::Eval::padded_version_string($v1);
            my $pv2 = WebService::GrowthBook::Eval::padded_version_string($v2);
            if($op eq 'eq'){
                is($pv1 eq $pv2, $result, "$v1 $op $v2");
            }
            elsif($op eq 'lt'){
                is($pv1 lt $pv2, $result, "$v1 $op $v2");
            }
            elsif($op eq 'gt'){
                is($pv1 gt $pv2, $result, "$v1 $op $v2");
            }
        }
    }
}

sub test_hash{
    my $cases = shift;
    for my $case ($cases->@*){
        my ($seed, $value, $version, $expected_result) = $case->@*;
        is(gbhash($seed, $value, $version), $expected_result, "gbhash($seed, $value, $version)");
    }
}