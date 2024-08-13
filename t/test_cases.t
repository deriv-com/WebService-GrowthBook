use strict;
use warnings;
use Test::Warnings;
use Test::More;
use WebService::GrowthBook::Eval qw(eval_condition);
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
ok(1);
done_testing;