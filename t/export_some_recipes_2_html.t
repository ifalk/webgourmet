use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### generate html files for some recipes - given by ids

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $test_ids = [
  '1302', # recipe w/ other recipe as ingredient
#  '1301', # refered by 1302
  '1305', # also refers to 1301
  '175',  # refers to 40
  '246', # recipe w/ ingredient subgroups
  '1185', # recipe w/ optional ingredients
  '1877', # recipe w/ image
  '1013', 
 '92',   # recipe w/o image, w/ link, cuisine
  '1485', # recipe w/o image, link, cuisine
  # w/ yield, preptime, cooktime, category, rating, source
  ];


#### collect data for recipe ids from database

my ($recipe_hash, $ingredient_hash) = Local::Modulino::DB2JSON->export2html_collect_data($dbh, $test_ids);

#### variables/constants needed for storing
####  - html files
####  - images
####  - names of image files 

my $html_dir = 'tests';
my $pic_dir = "$html_dir/pics";
my $id2image_file = Local::Modulino::DB2JSON->fetch_some_images($dbh, $test_ids, $pic_dir);
my $img_nbr = scalar(keys %{ $id2image_file });
print STDERR "Number of saved images: $img_nbr\n";
print STDERR Dumper($id2image_file);

### add file names of saved images to $recipe_hash
foreach my $id (keys %{ $id2image_file }) {
  $recipe_hash->{$id}->{'image_file'} = $id2image_file->{$id};
}

#### picture directory in html file: has to be relative to where the html file is
my $rel_picdir = 'pics';

my $max_rid = Local::Modulino::DB2JSON->get_max_id($dbh);
print STDERR "Max recipe id: $max_rid\n";

$dbh->disconnect();

########################################
### create html documents for given ids
########################################

use XML::LibXML;

foreach my $id (@{ $test_ids }) {

  my $title = $recipe_hash->{$id}->{'title'};
  print STDERR "id: $id, title: $title\n";

  #### Where to save the html file to
  my $file_name = "$html_dir/$title$id.html";


  ##################################
  ### Setup header of html document
  #
  # for header we need:
  # - title from recipe hash
  # - link to stylesheet: style.css

  my ($doc, $html) = Local::Modulino::DB2JSON->setup_html_header($title);


  ###########################################################
  ### the html body

  my $body = $doc->createElement('body');

  $html->appendChild($body);

  #############
  ### recipe header/description

  my $r_div = Local::Modulino::DB2JSON->make_html_recipe_description($doc, $recipe_hash, $id, $max_rid);

  ############# ingredients ###################

  $r_div = Local::Modulino::DB2JSON->make_html_recipe_ingredients($doc, $r_div, $ingredient_hash, $id);

  ######################################
  ### instructions

  $r_div = Local::Modulino::DB2JSON->make_html_recipe_instructions($doc, $r_div, $recipe_hash, $id);


  #################################################################
  ### modifications (i.e. notes)

  $r_div = Local::Modulino::DB2JSON->make_html_recipe_modifications($doc, $r_div, $recipe_hash, $id);

  $body->appendChild($r_div);

  $html->appendChild($body);

  $doc->setDocumentElement($html);


  $doc->toFile($file_name, 1);
}




