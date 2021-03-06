#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Release Coordinator, please update this file before starting every release
# and check the changes back into GIT for everyone's benefit.

# Things that normally need updating are:
#
# 1. Release number
# 2. Check the name prefix of all databases
# 3. Possibly add entries for core databases that are still on genebuilders' servers

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;
my $curr_eg_release = $curr_release - 53;
my $prev_eg_release = $curr_eg_release - 1;

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);

# ---------------------- CURRENT CORE DATABASES----------------------------------

# Use our mirror (which has all the databases)
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Or use the official staging servers
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-3:4160/$curr_release");
# and remove the Non-Vertebrates version of the shared species
#Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
#Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# before loading the Vertebrates version
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-1:4519/$curr_release");

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-3',
        -port   => 4275,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-1',
        -port   => 4240,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};
#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_master_plants' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-compara-prod-9', 'jalvarez_plants_load_members_101'],
    'compara_ptrees'   => [ 'mysql-ens-compara-prod-3', 'jalvarez_default_plants_protein_trees_101' ],

    # LASTZ dbs
    'lastz_batch_1a' => [ 'mysql-ens-compara-prod-4', 'jalvarez_plants_lastz_batch1_101a' ],
    'lastz_batch_1b' => [ 'mysql-ens-compara-prod-5', 'jalvarez_plants_lastz_batch1b_101' ],
    'lastz_batch_1c' => [ 'mysql-ens-compara-prod-7', 'jalvarez_plants_lastz_batch1_101c' ],
    'lastz_batch_1d' => [ 'mysql-ens-compara-prod-10', 'cristig_plants_lastz_batch1_101d' ],
    'unidir_lastz'   => [ 'mysql-ens-compara-prod-5', 'ensembl_plants_unidirectional_lastz' ],

    # synteny
    'compara_syntenies' => [ 'mysql-ens-compara-prod-5', 'jalvarez_plants_synteny_101' ],

    # EPO dbs
    ## rice
    'rice_epo_high_low' => [ 'mysql-ens-compara-prod-5', 'dthybert_rice_epo_100' ],
    'rice_epo_prev'     => [ 'mysql-ens-compara-prod-5', 'dthybert_rice_epo_100' ],
    'rice_epo_anchors'  => [ 'mysql-ens-compara-prod-5', 'cristig_generate_anchors_rice_99' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------
my $ancestral_dbs = {
    'ancestral_prev' => [ 'mysql-ens-compara-prod-5', "ensembl_ancestral_plants_${prev_eg_release}_$prev_release" ],
    'ancestral_curr' => [ 'mysql-ens-compara-prod-5', "ensembl_ancestral_plants_${curr_eg_release}_$curr_release" ],

    'rice_ancestral' => [ 'mysql-ens-compara-prod-5', 'dthybert_rice_ancestral_core_100' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
