=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Test

=head1 DESCRIPTION

Utility functions used in test scripts

=cut

package Bio::EnsEMBL::Compara::Utils::Test;

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Spec;
use File::Basename qw/dirname/;
use Test::More;

use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use Bio::EnsEMBL::Test::MultiTestDB;

=head2 GLOBAL VARIABLES

=over

=item repository_root

The path to the root of the repository. Kept here so that we don't need
to "compute" it again and again.

=back

=cut

my $repository_root;

=head2 get_repository_root

  Description : Return the path to the root of the repository. Note that
                this is constructed from the path to this module.

=cut

sub get_repository_root {
    return $repository_root if $repository_root;
    my $file_dir = dirname(__FILE__);
    $repository_root = File::Spec->catdir($file_dir, File::Spec->updir(), File::Spec->updir(), File::Spec->updir(), File::Spec->updir(), File::Spec->updir());
    $repository_root = File::Spec->abs2rel(abs_path($repository_root), getcwd());
    return $repository_root;
}

=head2 find_all_files

  Description : Return the list of all the files in the repository.
                Note that the path to the root of the repository
                from this file is hardcoded, as is the list of
                the top-level repository directories.

=cut

sub find_all_files {
    my @queue;
    my @files;

    # First populate the top-level sub-directories
    {
        my $starting_dir = get_repository_root();
        opendir(my $dirh, $starting_dir);
        my @dir_content = File::Spec->no_upwards(readdir $dirh);
        foreach my $f (@dir_content) {
            my $af = File::Spec->catfile($starting_dir, $f);
            # Exclude our .git directory, but also all directories that
            # have a .git (i.e. other Ensembl repositories installed on Travis)
            if ((-d $af) and ($f ne '.git') and !(-e File::Spec->catfile($af, '.git'))) {
                push @queue, $af;
            } elsif (-f $af) {
                push @files, $af;
            }
        }
        closedir $dirh;
    }

    # Recurse into the filesystem
    while ( my $f = shift @queue ) {
        if ( -l $f ) {
        } elsif ( -d $f ) {
            opendir(my $dirh, $f);
            push @queue, map {File::Spec->catfile($f, $_)} File::Spec->no_upwards(readdir $dirh);
            closedir $dirh;
        } else {
            push @files, $f;
        }
    }

    return @files;
}

=head2 create_multitestdb

  Description : Create a new MultiTestDB instance that can be used to
                create custom test databases on the fly.
  Returntype  : Bio::EnsEMBL::Test::MultiTestDB

=cut

sub create_multitestdb {
    my $compara_dir = get_repository_root();
    my $t_dir = "${compara_dir}/modules/t";

    # Initialize a MultiTestDB object
    my $multitestdb = bless {}, 'Bio::EnsEMBL::Test::MultiTestDB';
    $multitestdb->curr_dir($t_dir);
    $multitestdb->_rebless;
    $multitestdb->species('compara');
    return $multitestdb;
}


=head2 drop_database_if_exists

  Arg[1]      : Bio::EnsEMBL::Test::MultiTestDB $multitestdb. Object refering to the database server
  Arg[2]      : String $db_name. The database name
  Description : Drop the database if it exists and close the existing
                connection objects.
  Returntype  : None

=cut

sub drop_database_if_exists {
    my ($multitestdb, $db_name) = @_;
    if ($multitestdb->_db_exists($multitestdb->dbi_connection, $db_name)) {
        $multitestdb->_drop_database($multitestdb->dbi_connection, $db_name);
        $multitestdb->disconnect_dbi_connection;
    }
}


=head2 read_sqls

  Argument[1] : string $file_name. The path of the SQL file to read
  Argument[2] : (optional) boolean $with_fk (default false). Turn on to
                keep the foreign key constraints, otherwise they are removed
  Description : Read the content of the schema definition file and return
                it as a list of SQL statements with titles
  Returntype  : List of string pairs

=cut

sub read_sqls {
    my $sql_file = shift;
    my $with_fk  = shift;

    # Same code as in MultiTestDB::load_sql but without the few lines we don't need
    my $all_sql = '';
    work_with_file($sql_file, 'r', sub {
        my ($fh) = @_;
        my $is_comment = 0;
        while(my $line = <$fh>) {
            if ($is_comment) {
                $is_comment = 0 if $line =~ m/\*\//;
            } elsif ($line =~ m/\/\*/) {
                $is_comment = 1 unless $line =~ m/\*\//;
            } elsif ($line !~ /^#/ && $line !~ /^--( |$)/ && $line =~ /\S/) {
                #ignore comments and white-space lines
                $all_sql .= $line;
            }
        }
        return;
    });

    if ($with_fk) {
        $all_sql =~ s/ENGINE=MyISAM/ENGINE=InnoDB/g;
    }

    my @statements;
    foreach my $sql (split( /;/, $all_sql )) {
        $sql =~ s/^\n*//s;
        next unless $sql;
        if (!$with_fk) {
            # FOREIGN KEY constraints followed by something else (note the
            # trailing comma)
            $sql =~ s/^\s+FOREIGN\s+KEY[^,]+,//mg;
            # FOREIGN KEY constraints as the last line of the CREATE TABLE: no
            # trailing comma, so need to remove the one from the previous line
            $sql =~ s/,[\n\s]+FOREIGN\s+KEY.+$//m;
            # In case the regexp are still missing some cases
            die $sql if $sql =~ /FOREIGN/;
        }
        # $title will usually be something like "CREATE TABLE dnafrag"
        my $title = $sql;
        $title =~ s/\s+\(.*//s;
        push @statements, [$title, $sql];
    }

    return \@statements;
}


=head2 test_schema_compliance

  Arg[1]      : Bio::EnsEMBL::Test::MultiTestDB $multitestdb. Object refering to the database server
  Arg[2]      : String $db_name. The database name
  Arg[3]      : Arrayref of String pairs (arrayrefs), each being a statement title, and an actual SQL statement
  Arg[4]      : String $server_mode. Typically TRADITIONAL or ANSI
  Description : Execute all the statements in a new database and check that they pass individually
  Returntype  : A DBI database handle to the newly created database

=cut

sub test_schema_compliance {
    my ($multitestdb, $db_name, $statements, $server_mode) = @_;

    # Create the database and set the SQL mode
    drop_database_if_exists($multitestdb, $db_name);
    my $db = $multitestdb->create_and_use_db($multitestdb->dbi_connection(), $db_name);
    $db->do("SET SESSION sql_mode = '$server_mode'");

    # Test every statement
    foreach my $s (@$statements) {
        eval {
            $db->do($s->[1]);
            pass($s->[0]);
        };
        if (my $err_msg = $@) {
            fail($s->[0]);
            diag($err_msg);
        }
    }
    return $db;
}


=head2 load_statements

  Arg[1]      : Bio::EnsEMBL::Test::MultiTestDB $multitestdb. Object refering to the database server
  Arg[2]      : String $db_name. The database name
  Arg[3]      : Arrayref of String pairs (arrayrefs), each being a statement title, and an actual SQL statement
  Arg[4]      : (optional) String $test_name. A custom name to give to the test
  Description : Execute all the statements in a new database and check that they pass as a whole
  Returntype  : A DBI database handle to the newly created database

=cut

sub load_statements {
    my ($multitestdb, $db_name, $statements, $test_name) = @_;

    # Create the database and set the SQL mode
    drop_database_if_exists($multitestdb, $db_name);
    my $db = $multitestdb->create_and_use_db($multitestdb->dbi_connection(), $db_name);

    eval {
        foreach my $s (@$statements) {
            $db->do($s->[1]);
        };
    };
    if (my $err_msg = $@) {
        fail($test_name);
        diag($err_msg);
    } else {
        pass($test_name);
    }
    return $db;
}


=head2 get_schema_from_database

  Arg[1]      : DBI database handle $dbh
  Description : Queries the schema of the database
  Returntype  : Hashref {table name => Hashref {column number => column info}}
  Exceptions  : none

=cut

sub get_schema_from_database {
    my $dbh = shift;
    # For some reasons, column_info(undef, undef, '%', '%') doesn't
    # work on MySQL ... We need to call it on each table explicitly
    my $sth = $dbh->table_info(undef, undef, '%');
    my @table_names = keys %{ $sth->fetchall_hashref('TABLE_NAME') };
    my %schema;
    foreach my $t (@table_names) {
        $sth = $dbh->column_info(undef, undef, $t, '%');
        $schema{$t} = $sth->fetchall_hashref('ORDINAL_POSITION');
    }
    return \%schema;
}


=head2 test_command

  Arg[1]      : String or Array-ref $command
  Arg[2]      : String $test_name
  Description : Execute the command and check that the return code is 0.
                The command can be given as a string (which will be parsed
                by Perl's system() or the shell) or as an array-ref of
                strings.
  Returntype  : none

=cut

sub test_command {
    my ($command, $test_name) = @_;
    my $rc = system(ref($command) eq 'ARRAY' ? @$command : $command);
    if ($rc) {
        fail($test_name);
        diag("Return code:$? $!");
    } else {
        pass($test_name);
    }
}


1;
