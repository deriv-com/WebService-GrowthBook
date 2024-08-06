use strict;
use warnings;
use Test::More;
use_ok('WebService::GrowthBook::FeatureRule');
my $rule = WebService::GrowthBook::FeatureRule->new;
isa_ok($rule, 'WebService::GrowthBook::FeatureRule');
$rule = WebService::GrowthBook::FeatureRule->new(disable_sticky_bucketing => 1, fallback_attribute => 'id');
is($rule->fallback_attribute, undef, 'fall_back_attribute is undef since disabled sticky_bucketing');
done_testing;