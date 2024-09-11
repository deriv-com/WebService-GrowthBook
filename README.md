# NAME

WebService::GrowthBook - sdk of growthbook

# SYNOPSIS

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

# DESCRIPTION

    This module is a sdk of growthbook, it provides a simple way to use growthbook features.

# METHODS

## load\_features

load features from growthbook API

    $instance->load_features;

## is\_on

check if a feature is on

    $instance->is_on('feature_name');

Please note it will return undef if the feature does not exist.

## is\_off

check if a feature is off

    $instance->is_off('feature_name');

Please note it will return undef if the feature does not exist.

## get\_feature\_value

get the value of a feature

    $instance->get_feature_value('feature_name');

Please note it will return undef if the feature does not exist.

## set\_features

set features

    $instance->set_features($features);

## eval\_feature

evaluate a feature to get the value

    $instance->eval_feature('feature_name');

## set\_attributes

set attributes (can be set when creating gb object) and evaluate features

    $instance->set_attributes({attr1 => 'value1', attr2 => 'value2'});
    $instance->eval_feature('feature_name');

# SEE ALSO

- [https://docs.growthbook.io/](https://docs.growthbook.io/)
- [PYTHON VERSION](https://github.com/growthbook/growthbook-python)
