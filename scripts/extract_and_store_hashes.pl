use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);



use Getopt::Long 'HelpMessage';

my $args = [ @ARGV ];

GetOptions(
  'db=s' => \my $database,
  'recipe_json=s' => \(my $recipe_json_file_name = 'recipe_hash.json'),
  'ingredient_json=s' => \(my $ingredient_json_file_name = 'ingredient_hash.json'),
  'html_dir=s' =>\(my $html_dir = 'html_export'),
  'pic_dir=s' => \my $pic_dir
  ) or HelpMessage(1);

HelpMessage(1) unless $database;

unless ($pic_dir) {
  $pic_dir = "$html_dir/pics";
}


=head1 NAME

extract_and_store_hashes.pl - extract data from gourmet db and store it in json hashes.

Data is needed later to generate html files for recipes

=head1 SYNOPSIS

  --db,-d           Gourmet database file (required)
  --recipe_json     name of the file where recipe data is to be stored, defaults to recipe_hash.json
  --ingredient_json name of the file where ingredient data is to be stored, defaults to ingredient_hash.json
  --html_dir        name of directory where html files will be stored, defaults to html_export
  --pic_dir         name of directory where images will be stored, defaults to $html_dir/pics
  --help,-h         Print this help

=head1 VERSION

0.01

=cut

my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

#### collect data for recipe ids from database

my $recipe_hash = Local::Modulino::GourmetExport->fetch_all_recipes($dbh);

my $nbr_recipes = scalar(keys %{ $recipe_hash });
print STDERR "Extracted data for $nbr_recipes recipes\n";

my $ingredient_hash = Local::Modulino::GourmetExport->fetch_all_ingredients($dbh, $recipe_hash);
my $nbr_recipes_w_ings = scalar(keys %{ $ingredient_hash });
print STDERR "Found $nbr_recipes_w_ings recipes with ingredients\n";

#### add categories to recipe hash
$recipe_hash = Local::Modulino::GourmetExport->fetch_all_categories($dbh, $recipe_hash);

#### does every recipe have a category?
my $recipes_wo_cat = Local::Modulino::GourmetExport->recipes_wo_cat($recipe_hash);
my $nbr_recipes_wo_cat = scalar(keys %{ $recipes_wo_cat });
print STDERR "Found $nbr_recipes_wo_cat recipes wo a category\n";
print STDERR Dumper($recipes_wo_cat);
print STDERR Dumper($recipe_hash->{'1893'});


#### Need html directory at this stage! Image location is saved in recipe hash!
#### nicht so ideal...

$recipe_hash = Local::Modulino::GourmetExport->export2html_collect_all_images($dbh, $recipe_hash, $html_dir, $pic_dir);

$dbh->disconnect();

#### save recipe_hash and ingredient hash
my $json = encode_json($recipe_hash);
write_file($recipe_json_file_name, { binmode => ':raw' }, $json);

$json = encode_json($ingredient_hash);
write_file($ingredient_json_file_name, { binmode => ':raw' }, $json);


