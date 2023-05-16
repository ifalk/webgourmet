use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $recipe_json_file_name = 'recipe_hash.json';
my $ingredient_json_file_name = 'ingredient_hash.json';
my $id2file_name_json_file_name = 'id2file_name.json';


my $json = read_file($recipe_json_file_name, { binmode => ':raw' });
my $recipe_hash = decode_json($json);

$json = read_file($ingredient_json_file_name, { binmode => ':raw' });
my $ingredient_hash = decode_json($json);

$json = read_file($id2file_name_json_file_name, { binmode => ':raw' });
my $id2file_name = decode_json($json);

my @recipes_json;

foreach my $id (sort {$a <=> $b} (keys %{ $recipe_hash })[0..20]) {
  next unless (exists $id2file_name->{$id} and exists $id2file_name->{$id}->{'html_file_name'});

  ### do we need this?
  my $linkrecipe = $id2file_name->{$id}->{'html_file_name'};
  my $title = $recipe_hash->{$id}->{'title'};
  my $title_string = "<a href='$linkrecipe'>$title</a>";

  my @ing_searchfield;

  if (exists $ingredient_hash->{$id}) {
    foreach my $subgroup (keys %{ $ingredient_hash->{$id} }) {
      unless ($subgroup eq 'none') {
	push(@ing_searchfield, $subgroup);
      }
      foreach my $ing_array (@{ $ingredient_hash->{$id}->{$subgroup} }) {
	my $ing_name = $ing_array->[0];
	my $ing_key = $ing_array->[1]->{'ingkey'};
	push(@ing_searchfield, "$ing_name,$ing_key");
      }
    }
  }

  my $searchfield = join(',', map { $recipe_hash->{$id}->{$_} or '' } (qw(title instructions modifications source category)));
  if (@ing_searchfield) {
    my $ing_searchstring = join(',', @ing_searchfield);
    $searchfield = "$searchfield,$ing_searchstring";
  }

  my $entry = {
    'id' => $id,
    'title' => $title_string,
    'category' => $recipe_hash->{$id}->{'category'} ? $recipe_hash->{$id}->{'category'} : '',
    'yields' => $recipe_hash->{$id}->{'yields'} ? $recipe_hash->{$id}->{'yields'} : '0',
    'rating' => $recipe_hash->{$id}->{'rating'} ? $recipe_hash->{$id}->{'rating'} : '',
    'searchfield' => $searchfield,
  };
  push (@recipes_json, $entry);

  
}

$json = encode_json(\@recipes_json);
write_file('recipes_test.json', { binmode => ':raw' }, $json)
