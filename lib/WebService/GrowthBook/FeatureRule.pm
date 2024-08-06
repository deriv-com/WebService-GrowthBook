package WebService::GrowthBook::FeatureRule;
use strict;
use warnings;
no indirect;
use Object::Pad;

class WebService::GrowthBook::FeatureRule {
    field $id :param :reader //= undef;
    field $key :param :reader //= '';
    field $variations :param :reader //= undef;
    field $weights :param :reader //= undef;
    field $coverage :param :reader //= undef;
    field $condition :param :reader //= undef;
    field $namespace :param :reader //= undef;
    field $fore :param :reader //= undef;
    field $hash_atrribute :param :reader //= 'id';
    field $fallback_attribute :param :reader //= undef;
    field $hashVersion :param :reader //= 1;
    field $range :param :reader //= undef;
    field $ranges :param :reader //= undef;
    field $meta :param :reader //= undef;
    field $filters :param :reader //= undef;
    field $seed :param :reader //= undef;
    field $name :param :reader //= undef;
    field $phase :param :reader //= undef;
    field $disable_sticky_bucketing :param :reader //= undef;
    field $bucketVersion :param :reader //= 0;
    field $minBucketVersion :param :reader //= 0;
    field $parentConditions :param :reader //= undef;

    ADJUST {
        if($disable_sticky_bucketing){
            $fallback_attribute = undef;
        }
    }
    
    method to_hash {
        return {
            id => $id,
            key => $key,
            variations => $variations,
            weights => $weights,
            coverage => $coverage,
            condition => $condition,
            namespace => $namespace,
            fore => $fore,
            hash_atrribute => $hash_atrribute,
            fallback_attribute => $fallback_attribute,
            hashVersion => $hashVersion,
            range => $range,
            ranges => $ranges,
            meta => $meta,
            filters => $filters,
            seed => $seed,
            name => $name,
            phase => $phase,
            disable_sticky_bucketing => $disable_sticky_bucketing,
            bucketVersion => $bucketVersion,
            minBucketVersion => $minBucketVersion,
            parentConditions => $parentConditions,
        };
    }
}
