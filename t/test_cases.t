use strict;
use warnings;
use Test::Warnings;
use Test::More;
use WebService::GrowthBook;
use WebService::GrowthBook::Eval qw(eval_condition);
use WebService::GrowthBook::Util qw(gbhash get_bucket_ranges choose_variation get_query_string_override);
use JSON::MaybeUTF8 qw(decode_json_text);
use Path::Tiny;
use FindBin qw($Bin);

my $json_file = path("$Bin/cases.json");
my $test_cases = decode_json_text($json_file->slurp_utf8);

my $eval_condition_cases = $test_cases->{evalCondition};
for my $case (@$eval_condition_cases){
    my ($name, $condition, $attributes, $expected_result) = $case->@*;
    is(eval_condition($attributes, $condition), $expected_result, $name) or exit(0);
}

my $version_compare_cases = $test_cases->{versionCompare};
test_version_compare($version_compare_cases);
test_hash($test_cases->{hash});
test_get_bucket_range($test_cases->{getBucketRange});
test_feature($test_cases->{feature});
test_run($test_cases->{run});
test_choose_variation($test_cases->{chooseVariation});
test_get_query_string_override($test_cases->{getQueryStringOverride});
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

sub test_get_bucket_range{
    my $cases = shift;
    for my $case ($cases->@*){
        my ($name, $args, $expected) = $case->@*;
        my ($num_variations, $coverage, $weights) = $args->@*;
        my $actual = get_bucket_ranges($num_variations, $coverage, $weights);
        is_deeply($actual, $expected, $name);
    }
}

sub test_feature{
    my $cases = shift;
    for my $case ($cases->@*){
        my ($name, $ctx, $key, $expected) = $case->@*;
        #next unless $name eq 'empty experiment rule - c' or $name eq 'empty experiment rule - a';
        my $gb = WebService::GrowthBook->new(%$ctx);
        my $res = $gb->eval_feature($key);
        # I don't know why there is such line, but it is in py version test.
        if(exists($expected->{experiment})){
            $expected->{experiment} = WebService::GrowthBook::Experiment->new(%{$expected->{experiment}})->to_hash;
        }
        is_deeply($res->to_hash, $expected, $name);
    }
}

sub test_run{
    my $cases = shift;
    for my $case ($cases->@*){
        my ($name, $ctx, $exp, $value, $in_experiment, $hash_used) = $case->@*;
        my $gb = WebService::GrowthBook->new(%$ctx);
        my $res = $gb->run(WebService::GrowthBook::Experiment->new(%$exp));
        is_deeply($res->value, $value, "$name value");
        is_deeply($res->in_experiment, $in_experiment, "$name in_experiment");
        is_deeply($res->hash_used, $hash_used, "$name hash_used");
    }
}

sub test_choose_variation{
    my $cases = shift;
    for my $case ($cases->@*){
        my ($name, $n, $range, $expected) = $case->@*;
        my $result = choose_variation($n, $range);
        is($result, $expected, $name);
    }
}

sub test_get_query_string_override{
    my $cases = shift;
    for my $case ($cases->@*){
        my ($name, $id, $url, $num_variations, $expected) = $case->@*;
        is_deeply(get_query_string_override($id, $url, $num_variations), $expected, $name);
    }
}