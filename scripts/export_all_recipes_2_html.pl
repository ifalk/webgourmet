use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);


use Getopt::Long 'HelpMessage';

GetOptions(
  'db=s' => \my $database,
  'recipe_json=s' => \(my $recipe_json_file_name = 'recipe_hash.json'),
  'ingredient_json=s' => \(my $ingredient_json_file_name = 'ingredient_hash.json'),
  # 'id2file_name_json=s' => \(my $id2file_name_json_file_name = 'id2file_name.json'),
  'html_dir=s' =>\(my $html_dir = 'html_export'),
#### picture directory in html file: has to be relative to where the html file is
  'rel_pic_dir=s' => \(my $rel_picdir = 'pics')
  ) or HelpMessage(1);

=head1 NAME

export_all_recipes_2_html.pl - make html files for all recipes. 

Uses data extracted from gourmet db and stored in json files. Stores data needed for html index in json hash (writing to STDOUT).

=head1 SYNOPSIS

  --db,-d             Gourmet database file (optional, if present the maximal recipe id is extracted and added to the html files)
  --recipe_json       name of the file where recipe data is to be stored, defaults to recipe_hash.json
  --ingredient_json   name of the file where ingredient data is to be stored, defaults to ingredient_hash.json
  --html_dir          name of directory where html files will be stored, defaults to html_export
  --rel_picdir        name of directory where images will be stored, is relative to html_dir and defaults to pics
  --help,-h           Print this help

=head1 VERSION

0.01

=cut


my $json = read_file($recipe_json_file_name, { binmode => ':raw' });
my $recipe_hash = decode_json($json);

$json = read_file($ingredient_json_file_name, { binmode => ':raw' });
my $ingredient_hash = decode_json($json);


#### extract max recipe id (shows which recipes are older/newer)
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $max_rid;
if ($database) {
  my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

  $max_rid = Local::Modulino::GourmetExport->get_max_id($dbh);
  print STDERR "Max recipe id: $max_rid\n";

  #### No longer need to access db, disconnect
  $dbh->disconnect();
}


########################################
### create html documents for all recipes in db
########################################

my $nbr_recipes = scalar(keys %{ $recipe_hash });
print STDERR "Total number of recipes: $nbr_recipes\n";

my $id2file_name = Local::Modulino::GourmetExport->export2html_all($recipe_hash, $ingredient_hash, $max_rid, $html_dir, $rel_picdir);

my $json = encode_json($id2file_name);
write_file(\*STDOUT, $json);

