use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### extract data from db for recipes, store it in hashes.
### extract images, save them and add location (file name) to recipe hash
### hashes are then used to build html files

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);


#### collect data for recipe ids from database

my $recipe_hash = Local::Modulino::DB2JSON->fetch_all_recipes($dbh);

my $nbr_recipes = scalar(keys %{ $recipe_hash });
print STDERR "Extracted data for $nbr_recipes recipes\n";

# my $ingredient_hash = Local::Modulino::DB2JSON->fetch_all_ingredients($dbh, $recipe_hash);
# my $nbr_recipes_w_ings = scalar(keys %{ $ingredient_hash });
# print STDERR "Found $nbr_recipes_w_ings recipes with ingredients\n";

#### add categories to recipe hash
$recipe_hash = Local::Modulino::DB2JSON->fetch_all_categories($dbh, $recipe_hash);

#### does every recipe have a category?
my $recipes_wo_cat = Local::Modulino::DB2JSON->recipes_wo_cat($recipe_hash);
my $nbr_recipes_wo_cat = scalar(keys %{ $recipes_wo_cat });
print STDERR "Found $nbr_recipes_wo_cat recipes wo a category\n";
# print STDERR Dumper($recipes_wo_cat);
# print STDERR Dumper($recipe_hash->{'1893'});

my $html_dir='html_export';
$recipe_hash = Local::Modulino::DB2JSON->export2html_collect_all_images($dbh, $recipe_hash, $html_dir, $pic_dir);


#### No longer need to access db, disconnect
$dbh->disconnect();

#### save recipe_hash and ingredient hash
