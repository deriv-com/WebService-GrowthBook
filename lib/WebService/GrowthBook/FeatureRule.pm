package WebService::GrowthBook::FeatureRule;
use strict;
use warnings;
no indirect;
use Object::Pad;

class WebService::GrowthBook::FeatureRule {
    field $id :param //= undef;
    field $key :param //= '';
    field $variations :param //= undef;
    field $weights :param //= undef;
    field $coverage :param //= undef;
    field $condition :param :reader //= undef;
    field $namespace :param //= undef;
    field $fore :param //= undef;
    field $hash_atrribute :param //= 'id';
    field $fallback_attribute :param :reader //= undef;
    field $hashVersion :param //= 1;
    field $range :param //= undef;
    field $ranges :param //= undef;
    field $meta :param //= undef;
    field $filters :param //= undef;
    field $seed :param //= undef;
    field $name :param //= undef;
    field $phase :param //= undef;
    field $disable_sticky_bucketing :param //= undef;
    field $bucketVersion :param //= 0;
    field $minBucketVersion :param //= 0;
    field $parentConditions :param //= undef;

    ADJUST {
        if($disable_sticky_bucketing){
            $fallback_attribute = undef;
        }
    }
}
