package WebService::GrowthBook;
# ABSTRACT: ...

use strict;
use warnings;
no indirect;
use feature qw(state);
use Object::Pad;
use JSON::MaybeUTF8 qw(decode_json_text);
use Scalar::Util qw(blessed);
use Log::Any qw($log);
use WebService::GrowthBook::FeatureRepository;
use WebService::GrowthBook::Feature;
use WebService::GrowthBook::FeatureResult;
use WebService::GrowthBook::InMemoryFeatureCache;
use WebService::GrowthBook::Eval qw(eval_condition);
use WebService::GrowthBook::Util qw(gbhash in_range get_query_string_override);
use WebService::GrowthBook::Experiment;
use WebService::GrowthBook::Result;

our $VERSION = '0.003';

=head1 NAME

WebService::GrowthBook - sdk of growthbook

=head1 SYNOPSIS

    use WebService::GrowthBook;
    my $instance = WebService::GrowthBook->new(client_key => 'my key');
    $instance->load_features;
    if($instance->is_on('feature_name')){
        # do something
    }
    else {
        # do something else
    }
    my $string_feature = $instance->get_feature_value('string_feature');
    my $number_feature = $instance->get_feature_value('number_feature');
    # get decoded json
    my $json_feature = $instance->get_feature_value('json_feature');

=head1 DESCRIPTION

    This module is a sdk of growthbook, it provides a simple way to use growthbook features.

=cut

# singletons

class WebService::GrowthBook {
    field $enabled :param //= 1;
    field $url :param //= 'https://cdn.growthbook.io';
    field $client_key :param;
    field $features :param //= {};
    field $attributes :param :reader :writer //= {};
    field $cache_ttl :param //= 60;
    field $user :param //= {};
    field $forced_variations :param //= {};
    field $overrides :param //= {};
    field $sticky_bucket_service :param //= undef;

    field $cache //= WebService::GrowthBook::InMemoryFeatureCache->singleton;
    field $sticky_bucket_assignment_docs //= {};

    method load_features {
        my $feature_repository = WebService::GrowthBook::FeatureRepository->new(cache => $cache);
        my $loaded_features = $feature_repository->load_features($url, $client_key, $cache_ttl);
        if($loaded_features){
            $self->set_features($loaded_features);
            return 1;
        }
        return undef;
    }
    method set_features($features_set) {
        $features = {};
        for my $feature_id (keys $features_set->%*) {
            my $feature = $features_set->{$feature_id};
            if(blessed($feature) && $feature->isa('WebService::GrowthBook::Feature')){
                $features->{$feature->id} = $feature;
            }
            else {
                $features->{$feature_id} = WebService::GrowthBook::Feature->new(id => $feature_id, default_value => $feature->{defaultValue}, rules => $feature->{rules});
            }
        }
    }
    
    method is_on($feature_name) {
        my $result = $self->eval_feature($feature_name);
        return undef unless defined($result);
        return $result->on;
    }
    
    method is_off($feature_name) {
        my $result = $self->eval_feature($feature_name);
        return undef unless defined($result);
        return $result->off;
    }
    
    # I don't know why it is called stack. In fact it is a hash/dict
    method $eval_feature($feature_name, $stack){
        $log->debug("Evaluating feature $feature_name");
        if(!exists($features->{$feature_name})){
            $log->debugf("No such feature: %s", $feature_name);
            return WebService::GrowthBook::FeatureResult->new(feature_id => $feature_name, value => undef, source => "unknownFeature");
        }

        if ($stack->{$feature_name}) {
            $log->warnf("Cyclic prerequisite detected, stack: %s", $stack);
            return WebService::GrowthBook::FeatureResult->new(id => $feature_name, value => undef, source => "cyclicPrerequisite");
        }
        
        $stack->{$feature_name} = 1;

        my $feature = $features->{$feature_name};
        for my $rule (@{$feature->rules}){
            $log->debugf("Evaluating feature %s, rule %s", $feature_name, $rule.to_hash());
            if ($rule->parentConditions){
                my $prereq_res = $self->eval_prereqs($rule->parentConditions, $stack);
                if ($prereq_res eq "gate") {
                    $log->debugf("Top-lavel prerequisite failed, return undef, feature %s", $feature_name);
                    return WebService::GrowthBook::FeatureResult->new(id => $feature_name, value => undef, source => "prerequisite");
                }
                elsif ($prereq_res eq "cyclic") {
                    return WebService::GrowthBook::FeatureResult->new(id => $feature_name, value => undef, source => "cyclicPrerequisite");
                }
                elsif ($prereq_res eq "fail") {
                    $log->debugf("Skip rule becasue of failing prerequisite, feature %s", $feature_name);
                    continue;
                }
            }

            if ($rule->condition){
                if (!eval_condition($attributes, $rule->condition)){
                    $log->debugf("Skip rule because of failed condition, feature %s", $feature_name);
                    continue;
                }
            }

            if ($rule->force){
                if(!$self->is_included_in_rollout($rule->seed || $feature_name,
                    $rule->hash_attribute,
                    $rule->fallback_attribute,
                    $rule->range,
                    $rule->coverage,
                    $rule->hash_version
                )){
                    $log->debugf(
                        "Skip rule because user not included in percentage rollout, feature %s",
                        $feature_name,
                    );
                    continue;
                }
            }

            if($rule->variations){
                $log->warnf("Skip invalid rule, feature %s", $feature_name);
                continue;
            }
            my $exp = WebService::GrowthBook::Experiment->new(
                # TODO change $feature_name to $key
                # TODO change that $ method to _ method
                key                     => $rule->key || $feature_name,
                variations              => $rule->variations,
                coverage                => $rule->coverage,
                weights                 => $rule->weights,
                hash_attribute          => $rule->hash_attribute,
                fallback_attribute      => $rule->fallback_attribute,
                namespace               => $rule->namespace,
                hash_version            => $rule->hash_version,
                meta                    => $rule->meta,
                ranges                  => $rule->ranges,
                name                    => $rule->name,
                phase                   => $rule->phase,
                seed                    => $rule->seed,
                filters                 => $rule->filters,
                condition               => $rule->condition,
                disable_sticky_bucketing => $rule->disable_sticky_bucketing,
                bucket_version          => $rule->bucket_version,
                min_bucket_version      => $rule->min_bucket_version,
            ); 

            # TODO implement _run first


        }
        my $default_value = $feature->default_value;
    
        return WebService::GrowthBook::FeatureResult->new(
            feature_id => $feature_name,
            value => $default_value,
            source => "default" # TODO fix this, maybe not default
            );
    }

    method _run($experiment, $feature_id){
        # 1. If experiment has less than 2 variations, return immediately
        if (scalar @{$experiment->variations} < 2) {
            $log->warnf(
                "Experiment %s has less than 2 variations, skip", $experiment->key
            );
            return $self->_get_experiment_result($experiment, feature_id => $feature_id);
        }

        # 2. If growthbook is disabled, return immediately
        if (!$enabled) {
            $log->debugf(
                "Skip experiment %s because GrowthBook is disabled", $experiment->key
            );
            return $self->_get_experiment_result($experiment, feature_id => $feature_id);
        }      
        # 2.5. If the experiment props have been overridden, merge them in
        if (exists $overrides->{$experiment->key}) {
            $experiment->update($overrides->{$experiment->{key}});
        }

        # 3. If experiment is forced via a querystring in the URL
        my $qs = get_query_string_override(
            $experiment->key, $url, scalar @{$experiment->variations}
        );
        if (defined $qs) {
            $log->debugf(
                "Force variation %d from URL querystring, experiment %s",
                $qs,
                $experiment->key,
            );
            return $self->_get_experiment_result($experiment, variation_id => $qs, feature_id => $feature_id);
        }

        # 4. If variation is forced in the context
        if (exists $forced_variations->{$experiment->key}) {
            $log->debugf(
                "Force variation %d from GrowthBook context, experiment %s",
                $forced_variations->{$experiment->key},
                $experiment->key,
            );
            return $self->_get_experiment_result(
                $experiment, variation_id => $forced_variations->{$experiment->key}, feature_id => $feature_id
            );
        }

        # 5. If experiment is a draft or not active, return immediately
        if ($experiment->status eq "draft" or not $experiment->active) {
            $log->debugf("Experiment %s is not active, skip", $experiment->key);
            return $self->_get_experiment_result($experiment, feature_id => $feature_id);
        }

        # 6. Get the user hash attribute and value
        my ($hash_attribute, $hash_value) = $self->_get_hash_value($experiment->hash_attribute, $experiment->fallback_attribute);
        if (!$hash_value) {
            $log->debugf(
                "Skip experiment %s because user's hashAttribute value is empty",
                $experiment->key,
            );
            return $self->_get_experiment_result($experiment, feature_id => $feature_id);
        }

        my $assigned = -1;
        
        my $found_sticky_bucket = 0;
        my $sticky_bucket_version_is_blocked = 0;
        if ($sticky_bucket_service && !$experiment->disableStickyBucketing) {
            my $sticky_bucket = $self->_get_sticky_bucket_variation(
                experiment_key       => $experiment->key,
                bucket_version       => $experiment->bucketVersion,
                min_bucket_version   => $experiment->minBucketVersion,
                meta                 => $experiment->meta,
                hash_attribute       => $experiment->hashAttribute,
                fallback_attribute   => $experiment->fallbackAttribute,
            );
            $found_sticky_bucket = $sticky_bucket->{variation} >= 0;
            $assigned = $sticky_bucket->{variation};
            $sticky_bucket_version_is_blocked = $sticky_bucket->{versionIsBlocked};
        }


        if ($found_sticky_bucket) {
            $log->debugf(
                "Found sticky bucket for experiment %s, assigning sticky variation %s",
                $experiment->key, $assigned
            );
        }

        # Some checks are not needed if we already have a sticky bucket
        else {
            if ($experiment->filters){

                # 7. Filtered out / not in namespace
                if ($self->_is_filtered_out($experiment->{filters})) {
                    $log->debugf(
                        "Skip experiment %s because of filters/namespaces", $experiment->key
                    );
                    return $self->_get_experiment_result($experiment, feature_id => $feature_id);
                }
            }
        }

            # TODO here
    }

    method _is_filtered_out($filters) {
    
        foreach my $filter (@$filters) {
            my ($dummy, $hash_value) = $self->_get_hash_value($filter->{attribute} // "id");
            if ($hash_value eq "") {
                return 0;
            }
    
            my $n = gbhash($filter->{seed} // "", $hash_value, $filter->{hashVersion} // 2);
            if (!defined $n) {
                return 0;
            }
    
            my $filtered = 0;
            foreach my $range (@{$filter->{ranges}}) {
                if (in_range($n, $range)) {
                    $filtered = 1;
                    last;
                }
            }
            if (!$filtered) {
                return 1;
            }
        }
        return 0;
    }    

    method _get_sticky_bucket_assignments($attr = '', $fallback = ''){
        my %merged;
    
        my ($dummy, $hash_value) = $self->_get_hash_value($attr);
        my $key = "$attr||$hash_value";
        if (exists $sticky_bucket_assignment_docs->{$key}) {
            %merged = %{ $sticky_bucket_assignment_docs->{$key}{assignments} };
        }
    
        if ($fallback) {
            ($dummy, $hash_value) = $self->_get_hash_value($fallback);
            $key = "$fallback||$hash_value";
            if (exists $self->{_sticky_bucket_assignment_docs}{$key}) {
                # Merge the fallback assignments, but don't overwrite existing ones
                while (my ($k, $v) = each %{ $sticky_bucket_assignment_docs->{$key}{assignments} }) {
                    $merged{$k} //= $v;
                }
            }
        }
    
        return \%merged;
    }

    method _get_sticky_bucket_variation($experiment_key, $bucket_version = 0, $min_bucket_version = 0, $meta = {}, $hash_attribute = undef, $fallback_attribute = undef){ 
        my $id = $self->_get_sticky_bucket_experiment_key($experiment_key, $bucket_version);


        my $assignments = $self->_get_sticky_bucket_assignments($hash_attribute, $fallback_attribute);
        if ($self->_is_blocked($assignments, $experiment_key, $min_bucket_version)) {
            return {
                variation => -1,
                versionIsBlocked => 1
            };
        }

        my $variation_key = $assignments->{$id};
        if (!$variation_key) {
            return {
                variation => -1
            };
        }

        # Find the key in meta
        my $variation = -1;
        for (my $i = 0; $i < @$meta; $i++) {
            if ($meta->[$i]->{key} eq $variation_key) {
                $variation = $i;
                last;
            }
        }

        if ($variation < 0) {
            return {
                variation => -1
            };
        }

        return { variation => $variation };
    }

    method _is_blocked($assignments, $experiment_key, $min_bucket_version = 0){
        if ($min_bucket_version > 0) {
            for my $i (0 .. $min_bucket_version - 1) {
                my $blocked_key = $self->_get_sticky_bucket_experiment_key($experiment_key, $i);
                if (exists $assignments->{$blocked_key}) {
                    return 1;
                }
            }
        }
        return 0;
    }

    method _get_sticky_bucket_experiment_key($experiment_key, $bucket_version = 0){
        return $experiment_key . "__" . $bucket_version;
    }

    method _get_experiment_result($experiment, $variation_id = -1, $hash_used = 0, $feature_id = undef, $bucket = undef, $sticky_bucket_used = 0){ 
        my $in_experiment = 1;
        if ($variation_id < 0 || $variation_id > @{$experiment->{variations}} - 1) {
            $variation_id = 0;
            $in_experiment = 0;
        }
    
        my $meta;
        if ($experiment->meta) {
            $meta = $experiment->meta->[$variation_id];
        }
    
        my ($hash_attribute, $hash_value) = $self->_get_orig_hash_value($experiment->hash_attribute, $experiment->fallback_attribute);
    
        return WebService::GrowthBook::Result->new(
            feature_id         => $feature_id,
            in_experiment      => $in_experiment,
            variation_id       => $variation_id,
            value              => $experiment->variations->[$variation_id],
            hash_used          => $hash_used,
            hash_attribute     => $hash_attribute,
            hash_value         => $hash_value,
            meta               => $meta,
            bucket             => $bucket,
            sticky_bucket_used => $sticky_bucket_used
        );
    }

    method _is_included_in_rollout($seed, $hash_attribute, $fallback_attribute, $range, $coverage, $hash_version){
        if (!defined($coverage) && !defined($range)){
            return 1;
        }
        my $hash_value;
        (undef, $hash_value) = $self->_get_hash_value($hash_attribute, $fallback_attribute);
        if($hash_value eq "") {
            return 0;
        }

        my $n = gbhash($seed, $hash_value, $hash_version || 1);

        if (!defined($n)){
            return 0;
        }

        if($range){
            return in_range($n, $range);
        }
        elsif($coverage){
            return $n < $coverage;
        }

        return 1;
    }

    method _get_hash_value($attr, $fallback_attr){
        my $val;
        ($attr, $val) = $self->_get_orig_hash_value($attr, $fallback_attr);
        return ($attr, "$val");
    }
    
    method _get_orig_hash_value($attr, $fallback_attr){
        $attr ||= "id";
        my $val = "";
        
        if (exists $attributes->{$attr}) {
            $val = $attributes->{$attr} || "";
        } elsif (exists $user->{$attr}) {
            $val = $user->{$attr} || "";
        }

        # If no match, try fallback
        if ((!$val || $val eq "") && $fallback_attr && $self->{sticky_bucket_service}) {
            if (exists $attributes->{$fallback_attr}) {
                $val = $attributes->{$fallback_attr} || "";
            } elsif (exists $user->{$fallback_attr}) {
                $val = $user->{$fallback_attr} || "";
            }
        
            if (!$val || $val ne "") {
                $attr = $fallback_attr;
            }
        }
        
        return ($attr, $val);
    }

    method eval_prereqs($parent_conditions, $stack){
        foreach my $parent_condition (@$parent_conditions) {
            my $parent_res = $self->$eval_feature($parent_condition->{id}, $stack);
    
            if ($parent_res->{source} eq "cyclicPrerequisite") {
                return "cyclic";
            }
    
            if (!eval_condition({ value => $parent_res->{value} }, $parent_condition->{condition})) {
                if ($parent_condition->{gate}) {
                    return "gate";
                }
                return "fail";
            }
        }
        return "pass";
    }
    method eval_feature($feature_name){
        return $self->$eval_feature($feature_name, {});
    }
   
    method get_feature_value($feature_name, $fallback = undef){
        my $result = $self->eval_feature($feature_name);
        return $fallback unless defined($result->value);
        return $result->value;
    }
}

=head1 METHODS

=head2 load_features

load features from growthbook API

    $instance->load_features;

=head2 is_on

check if a feature is on

    $instance->is_on('feature_name');

Please note it will return undef if the feature does not exist.

=head2 is_off

check if a feature is off

    $instance->is_off('feature_name');

Please note it will return undef if the feature does not exist.

=head2 get_feature_value

get the value of a feature

    $instance->get_feature_value('feature_name');

Please note it will return undef if the feature does not exist.

=head2 set_features

set features

    $instance->set_features($features);

=head2 eval_feature

evaluate a feature to get the value

    $instance->eval_feature('feature_name');

=cut

1;


=head1 SEE ALSO

=over 4

=item * L<https://docs.growthbook.io/>

=item * L<PYTHON VERSION|https://github.com/growthbook/growthbook-python>

=back

