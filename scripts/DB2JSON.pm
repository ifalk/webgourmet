#!/usr/bin/perl
package Local::Modulino::DB2JSON;

__PACKAGE__->run( @ARGV ) unless caller();

use warnings;
use strict;
use English;

use Data::Types qw(:all);
use List::MoreUtils qw(each_array);

use Data::Dumper;
use Carp;
use Carp::Assert;

use Pod::Usage;
use Getopt::Long;

use utf8;

=head1 NAME

perl db2json.pl 

=head1 USAGE

   perl db2json.pl recipes.db

=head1 DESCRIPTION

Reads gourmet recipe db (sqlite) and produces a json data structure, written to STDOUT

=head1 REQUIRED ARGUMENTS

The recipe db

=head1 OPTIONS

=cut

binmode(STDERR, 'encoding(UTF-8)');
#binmode(STDOUT, 'encoding(UTF-8)');

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON;

use strict;

sub run
{

  unless (@ARGV) { pod2usage(2) }; 

  my $database = $ARGV[0];

  my $class = shift;

  my $dbh = $class->get_db_handle($database);

  my $some_recipe_ids = [ qw(246 1122 1302) ];

  my $sth = $class-> fetch_some_ingredients($dbh, $some_recipe_ids);

  my $recipes_ing = $class->handle_ingredients($sth);

  print STDERR Dumper($recipes_ing);
}

sub get_last_access
{
  my $class = shift;
  my $database = shift;


  my $last_access = 'undef';
  
  my $dbh = $class->get_db_handle($database);
  my $stmt = qq(select date(last_access, 'unixepoch') from info;);
  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  $last_access = ($sth->fetchrow_array())[0];

  $dbh->disconnect();
  return $last_access;

}

sub get_db_handle
{


  my $class = shift;
  my $database = shift;

  my $driver = "SQLite";
  my $dsn = "DBI:$driver:dbname=$database";
  my $userid = "";
  my $password = "";
  my $dbh = DBI->connect($dsn, $userid, $password, { 
    RaiseError => 1,
    sqlite_open_flags => SQLITE_OPEN_READONLY,
    sqlite_unicode => 1, 
			 })
    or die $DBI::errstr;

  print STDERR "Opened database successfully\n";

  return $dbh;
}

sub fetch_some_ingredients
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;

# get ingredients and build id -> ingredient hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my $select_fields = qq(recipe_id,refid,unit,amount,rangeamount,item,ingkey,optional,inggroup);

  my $stmt = qq(select $select_fields from ingredients where recipe_id in ($recipe_id_string) and deleted=0;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $ing_hash = {};

  while (my $ing_list = $sth->fetchrow_hashref()) {

    my $recipe_id = $ing_list->{recipe_id};

    my $item = $ing_list->{item};

    my $unit = $ing_list->{unit};
    my $amount = $class->stringify_amounts($ing_list->{amount}, $ing_list->{rangeamount});
    my $optional = $ing_list->{optional};
    my $ingkey = $ing_list->{ingkey};

    my $ing_group = $ing_list->{inggroup};
    unless ($ing_group) {
      $ing_group = 'none';
    }

    my %fields = (
      'unit' => $unit,
      'amount' => $amount,
      'optional' => $optional,
      'ingkey' => $ingkey
    );

    my $item_hash;

    while ( my ($key, $value) = each(%fields) ) {
      # $ing_hash->{$recipe_id}->{$ing_group}->{$item}->{$key} = $value;
      $item_hash->{$key} = $value;
    };

    if ($unit and ($unit eq 'recipe')) {
      # $ing_hash->{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
      $item_hash->{'refid'} = $ing_list->{'refid'};
    }

    push(@{ $ing_hash->{$recipe_id}->{$ing_group} }, [ $item => $item_hash ]);
  }

  return $ing_hash;
}



sub fetch_ingredients
{
  my $class = shift;
  my $dbh = shift;

# get ingredients and build id -> ingredient hash

  my $ing_stmt = qq(select * from ingredients); 
  my $ing_sth = $dbh->prepare( $ing_stmt);
  my $rv = $ing_sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $ing_sth;
}

sub fetch_amounts
{

  # fetch distinct amounts in ingredient table (for testing)

  my $class = shift;
  my $dbh = shift;


  my $stmt = qq(select distinct amount from ingredients); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

}

sub fetch_images
{
  # fetch images (for testing)

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select id, image, thumb from recipe where deleted=0);
  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;
}

sub fetch_inggroups
{
  # fetch inggroups

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct inggroup from ingredients); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};

sub fetch_recipes_wo_inggroup
{
  # fetch inggroups

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct recipe_id from ingredients where inggroup is null or inggroup = '';); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};

sub fetch_units
{
  # fetch units

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct unit from ingredients); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};


sub fetch_recipes_wo_unit
{
  # fetch units

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct recipe_id from ingredients where unit is null or unit = '';); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};

sub fetch_some_recipes
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;

# get recipe description and build id -> description hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });
  my $select_fields = qq(id,title,instructions,modifications,cuisine,rating,source,strftime('%H:%M', preptime, 'unixepoch'),strftime('%H:%M', cooktime, 'unixepoch'),servings,link,date(last_modified, 'unixepoch'),yields,yield_unit,image);
  my @col_names = qw(title instructions modifications cuisine rating source preptime cooktime servings link last_modified yields yield_unit image);
  my $stmt = qq(select $select_fields  from recipe where id in ($recipe_id_string) and deleted=0;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $recipe_hash = {};

  while (my @col_values = $sth->fetchrow()) {
    my $id = shift(@col_values); # remove value for 'id'

    my $col_hash={};
    my $ea = each_array(@col_names, @col_values);
    while (my ($col_name, $col_value) = $ea->()) {
      $col_hash->{$col_name} = $col_value;
    }

    ### these fields are just copied
    foreach my $col_name (qw(title instructions modifications cuisine last_modified image)) {
      $recipe_hash->{$id}->{$col_name} = $col_hash->{$col_name};
    }

    ### strings for times
    foreach my $time (qw(preptime cooktime)) {
      $recipe_hash->{$id}->{$time} = $class->stringify_db_time($col_hash->{$time});
    }


    ### strings for yields
    $recipe_hash->{$id}->{yields} = $class->stringify_yields($col_hash->{servings}, $col_hash->{yields}, $col_hash->{yield_unit});

    ### string for rating
    $recipe_hash->{$id}->{rating} = $class->stringify_db_rating($col_hash->{rating});

    ### strings for source and link
    my ($source, $link) = $class->stringify_source_link($col_hash->{source}, $col_hash->{link});
    $recipe_hash->{$id}->{source} = $source;
    $recipe_hash->{$id}->{link} = $link;
    
  }
  
  return $recipe_hash;
}

sub fetch_some_categories
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;
  my $recipe_hash = shift;

  # get categories and build id -> categories hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my $select_fields = qq(recipe_id,category);

  my $stmt = qq(select $select_fields from categories where recipe_id in ($recipe_id_string)); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $cat_hash = {};

  while (my ($recipe_id, $category) = $sth->fetchrow()) {
    $cat_hash->{$recipe_id}->{$category}++;
  }

  ### if recipe hash is given update it with categories and return it
  if ($recipe_hash) {
    foreach my $id (keys %{ $cat_hash }) {
      my $cat_string = join(', ', keys %{ $cat_hash->{$id} });
      $recipe_hash->{$id}->{'category'} = $cat_string;
    }
    return $recipe_hash;
  }
  
  return $cat_hash;
  
}

sub fetch_some_images
  ### gets images for given ids from database
  ### saves them as pic_dir/id.jpg
  ### returns a reference to a hash: id -> saved image file
  ### parameters
  ### 1. database handle
  ### 2. recipe ids for which to get images (array ref)
  ### 3. optional: pic_dir, directory where to save images (created if it doesn't exist
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;
  my $pic_dir = shift;


  die 'Need recipe ids (2nd par) for this function' unless $recipe_ids;
  unless ($pic_dir) {
    $pic_dir = 'pics';
  }
  
  
  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my $select_fields = qq(id,image);

  my $stmt = qq(select $select_fields from recipe where id in ($recipe_id_string)); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }



  my %id2image;

  while (my ($id, $img) = $sth->fetchrow()) {
    if ($img) {
      $id2image{$id} = $img;
    }
  }

  $dbh->disconnect();

  my $img_nbr = scalar(keys %id2image);

  my $id2img_file = {};
  unless ($img_nbr) { return $id2img_file };

  use File::Path qw(make_path);
  eval { make_path($pic_dir) };
  if ($@) {
    die "Couldn't create $pic_dir: $@";
  }

  foreach my $id (keys %id2image) {
    my $img_file = "$pic_dir/$id.jpg";
    open my $fh, '>', $img_file or die $!;
    binmode $fh;
    print $fh $id2image{$id};
    close $fh;

    $id2img_file->{$id} = $img_file;
  }

  return $id2img_file;
}


sub handle_ingredients
{
  my $class = shift;
  my $ing_sth = shift;
  my $recipes_ing = {};

  while (my $ing_list = $ing_sth->fetchrow_hashref()) {
    next if ($ing_list->{deleted});

    my $recipe_id = $ing_list->{recipe_id};

    my $item = $ing_list->{item};

    my $ing_group = $class->handle_inggroup($ing_list->{inggroup});
    
    my $unit = $class->handle_unit($ing_list->{unit});

    my $amount = $class->handle_amount($ing_list->{amount});

    my $optional = $class->handle_optional($ing_list->{optional});

    my %fields = (
      'unit' => $unit,
	'amount' => $amount,
	'optional' => $optional
    );


    while ( my ($key, $value) = each(%fields) ) {
      if ($recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{$key}) {
	$recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{$key} = $value;
      };
    };

    if ($unit and ($unit eq 'recipe')) {
      $recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
    }
  }


  return $recipes_ing;
};

sub stringify_amounts
{
  my $class = shift;
  my $db_amount = shift;
  my $db_rangeamount = shift;

  my $amount = $class->float_to_frac($db_amount, 0.02);
  my $rangeamount = $class->float_to_frac($db_rangeamount, 0.02);

  my $astring = $amount;

  if ($amount and $rangeamount) {
    my $join_string = '-';
    if ($db_rangeamount < $db_amount) {
      $join_string = ' ';
    }
    $astring = join($join_string, $amount, $rangeamount);
  }

  return $astring;
}

sub stringify_yields
{
  my $class = shift;
  my $db_servings = shift;
  my $db_yields = shift;
  my $yield_unit = shift;
  unless ($yield_unit) {
    $yield_unit = '';
  };

  my $servings = $class->float_to_frac($db_servings, 0.02);
  my $yields = $class->float_to_frac($db_yields, 0.02);

  my $yield_string = '';

  if ($servings) {
    $yield_string = "$servings servings";
  }

  unless ($yield_unit) {
    return $yields;
  }

  if ($yields) {
    $yield_string = join(' ', $yields, $yield_unit); 
  }

  return $yield_string;
}


sub float_to_frac {
  my $class = shift;
  my $n = shift;
  my $approx = shift;

  unless ($approx) {
    $approx = 0.01;
  }

  my %keep_divisors = (
    2 => 1,
    3 => 1,
    4 => 1,
    5 => 1,
    6 => 1,
    8 => 1,
    10 => 1,
    16 => 1
  );
  
  unless ($n) {
    return '';
  }

  if (is_whole($n)) {
    return $n;
  }
  
  my $i = int($n);
  my $rem = $n - $i;

  if ($rem and $rem<$approx) {
    return "$i";
  }
  
  my ($h, $k) = $class->fractify($rem, $approx);
  if ($keep_divisors{$k}) {
    if ($i) {
      return "$i $h/$k";
    }
    return "$h/$k";
  }

  my $rounded = sprintf("%.2f", $n);
  return $rounded;

}

sub fractify {
  my $class = shift;
  my $n = shift;
  my $approx = shift;

  if ($n eq '') { die "number required\n"; }

  unless ($approx) {
    $approx = 0.01;
  }

  
  use Math::BigInt;
  use Math::BigRat;

  my $x = my $y = Math::BigRat->new($n)->babs();
  my $h = my $k1 = Math::BigInt->new(1);
  my $k = my $h1 = Math::BigInt->new(0);

  while (1) {
    my $t = $y->as_int();
    ($h, $h1) = ($t * $h + $h1, $h);
    ($k, $k1) = ($t * $k + $k1, $k);
    my $val = Math::BigRat->new($h, $k);
    my $err = $val - $x;
    # my $out = sprintf "%s: %s / %s = %.16g (%.1g)\n", $t, $h, $k, $val, $err;
    # print STDERR $out, "\n";
    last if (abs($err) < $approx);
    $y -= $t or last;
    $y = 1 / $y;
  }

  return ($h, $k);
}

sub stringify_db_time
{
  my $class = shift;

  ### db_time is a string as returned by strftime('%H:%M', ..., 'unixepoch');
  my $db_time = shift;


  my $tstring = '';

  unless ($db_time) { return $tstring; };

  my ($db_hours, $db_minutes) = split(':', $db_time);

  my $hours = $db_hours =~ s{^0+}{}r;
  my $min = $db_minutes =~ s{^0+}{}r;

  # print STDERR "db hours: $db_hours, converted: $hours\n";
  # print STDERR "db_min: $db_minutes, converted: $min\n";

  unless ($hours) {
    if ($min) {
      return "$min min";
    } else {
      return '';
    }
  }


  $tstring = "$hours h";

  unless ($min) {
    return $tstring;
  }

  return "$tstring $min min";
  
}

sub stringify_db_rating
{
  my $class = shift;

  ### db_rating  is an integer, which is null or at least 1 and at most 10.
  
  my $db_rating = shift;


  my $rstring = '';

  unless ($db_rating) { return $rstring; };
  if ($db_rating > 10) { return '' }; # rating not valid

  $rstring = $db_rating / 2;
  return "$rstring/5 Sterne";
}

sub stringify_source_link
{
  my $class = shift;

  ### 
  my $db_source = shift;
  my $db_link = shift;

  my $sstring = '';
  my $lstring = '';

  unless ($db_source or $db_link) {
    return ($sstring, $lstring);
  }

  unless ($db_source) {
    return ($sstring, "$db_link");
  }

  if ($db_link) {
    $lstring = "$db_link";
  }

  if ($db_source =~ m/^http/) {
    if ($db_link) {
      if ("$db_source" eq "$db_link") {
	return ('', $lstring);
      } else {
	return ("$db_source", $lstring);
      }
    } else {
      return ("$db_source", "$db_source");
    }
  } else {
    return ("$db_source", "$lstring"); 
  }

}

sub ingredient_subgroup_2_html
  #### build html ul Element for ingredient subgroup
  #### return this ul Element
{
  my $class = shift;
  my $ingredient_hash = shift;
  my $id = shift;
  my $subgroup = shift; # default = 'none'
  my $doc = shift;

  unless ($ingredient_hash) { die "Argument missing: ingredient hash\n" };
  unless ($id) { die "Argument missing: recipe id\n" };
  unless ($subgroup) { $subgroup = 'none' };
  unless ($doc) { die "Argument missing: html document element (needed to create ul)\n" };

  my $ing_ref = $ingredient_hash->{$id};
  unless ($ing_ref->{$subgroup}) {
    die "There is no subgroup $subgroup for id $id\n";
  }

  my $ul = $doc->createElement('ul');
  $ul->setAttribute('class', 'ing');

  my %li_att_name_value = (
    'class' => 'ing',
    'itemprop' => 'ingredients'
    );


  foreach my $ing (@{ $ing_ref->{$subgroup} }) {
    my ($ing_name, $ing_atts) = @{ $ing };
    my @comp = @{ $ing_atts }{ qw(amount unit) };

    my $ing_string = join(' ', @comp, $ing_name);
    if ($ing_atts->{'optional'}) {
      $ing_string = "$ing_string (optional)";
    }
    my $li = $doc->createElement('li');
    foreach my $att_name (keys %li_att_name_value) {
      $li->setAttribute($att_name, $li_att_name_value{$att_name});
    }
    $li->appendText($ing_string);
    $ul->appendChild($li);
  }
  
  return $ul;
}

__END__

