package WebService::GrowthBook::Result;

use strict;
use warnings;
use Object::Pad;


class WebService::Growthbook::Result{
    field $variation_id :param :reader;
    field $in_experiment :param :reader;
    field $value :param :reader;
    field $hash_used :param :reader;
    field $hash_attribute :param :reader;
    field $hash_value :param :reader;
    field $feature_id :param :reader;
    field $bucket :param :reader //= undef;
    field $sticky_bucket_used :param :reader //= 0;
    field $meta :param //= undef;

    field $key :reader //= undef;
    field $name :reader //= "";
    field $passthrough :reader //= 0;; 

    ADJUST {
        $name = $meta->{name} if exists $meta->{name};
        $key = $meta->{key} if exists $meta->{key};
        $passthrough = $meta->{passthrough} if exists $meta->{passthrough};
    }

    method to_dict {
        my %obj = (
            feature_id         => $feature_id,
            variation_id       => $variation_id,
            in_experiment      => $in_experiment,
            value              => $value,
            hash_used          => $hash_used,
            hash_attribute     => $hash_attribute,
            hash_value         => $hash_value,
            key                => $key,
            sticky_bucket_used => $sticky_bucket_used,
        );
    
        $obj{bucket} = $self->{bucket} if defined $self->{bucket};
        $obj{name} = $self->{name} if $self->{name};
        $obj{passthrough} = 1 if $self->{passthrough};
    
        return \%obj;
    }


}

1;