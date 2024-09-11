use strict;
use warnings;
use WebService::GrowthBook;
use WebService::GrowthBook::FeatureRepository;
use Data::Dumper;
use Log::Any::Adapter qw(Stdout);

my $key = $ENV{GROWTHBOOK_KEY};
my $gb = WebService::GrowthBook->new(client_key => $key);
$gb->load_features();
print "bool feature is on:", $gb->is_on('bool-feature'), "\n";
print "bool feature is off:", $gb->is_off('bool-feature'), "\n";
print "string feature:", $gb->get_feature_value('string-feature'),"\n";
print "number feature:", $gb->get_feature_value('number-feature'),"\n";
print "json feature:", Dumper($gb->get_feature_value('json-feature')),"\n";
$gb->set_attributes({ id => 1});
print "bool attribute: ", ($gb->is_on('bool-attribute')),"\n";
$gb->set_attributes({ id => 123});
print "bool attribute: ", ($gb->is_on('bool-attribute')),"\n";
