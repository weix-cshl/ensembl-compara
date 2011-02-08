package Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter;
  
  my $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1
  );
  
  my $pt = $dba->get_ProteinTreeAdaptor()->fetch_node_by_node_id(2);
  
  $w->write_trees($pt);
  
  print $w->document()->toString(1), "\n";

=head1 DESCRIPTION

Used as a way of emitting Compara ProteinTrees in a format which conforms
to L<PhyloXML|http://www.phyloxml.org/>. The code is built to work with
instances of L<Bio::EnsEMBL::Compara::ProteinTree> but can be extended to
operate on any tree structure provided by the Compara Graph infrastructure.

The code provides a number of property extensions to the existing PhyloXML
standard:

=over 8

=item B<Compara:genome_db_name>

Used to show the name of the GenomeDB of the species found. Useful when 
taxonomy is not exact.

=item B<Compara:dubious_duplication>

Indicates locations of potential duplications we are unsure about

=back

The same document is persistent between write_trees() calls so to create
a new XML document create a new instance of this object.

=head1 SUBROUTINES/METHODS

See inline

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 REQUIREMENTS

=over 8

=item L<XML::LibXML>

=back

=head1 LICENSE

 Copyright (c) 1999-2011 The European Bioinformatics Institute and
 Genome Research Limited.  All rights reserved.

 This software is distributed under a modified Apache license.
 For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <dev@ensembl.org>.

 Questions may also be sent to the Ensembl help desk at
 <helpdesk@ensembl.org>.

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

use XML::LibXML;

my $phylo_uri = 'http://www.phyloxml.org';
my $xsi_uri = 'http://www.w3.org/2001/XMLSchema-instance';

=pod

=head2 new()

  Arg[CDNA]             : Boolean; indicates if we want CDNA emitted or peptide.
                          Defaults to B<true>. 
  Arg[SOURCE]           : String; the source of the stable identifiers.
                          Defaults to B<Unknown>.
  Arg[ALIGNED]          : Boolean; indicates if we want to emit aligned
                          sequence. Defaults to B<false>.
  Arg[NO_SEQUENCES]     : Boolean; indicates we want to ignore sequence 
                          dumping. Defaults to B<false>.                          
  Description : Creates a new tree writer object. 
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -ALIGNED => 1
                );
  Status      : Stable  
  
=cut

sub new {
  my ($class, @args) = @_;
  my ($cdna, $source, $aligned, $no_sequences) = 
    rearrange([qw(cdna source aligned no_sequencess)], @args);
  
  $source ||= 'Unknown';
  $cdna ||= 1;
  
  my $self = bless({}, ref($class) || $class);
  
  if( ($cdna || $aligned) && $no_sequences) {
    warning '-CDNA or -ALIGNED was specified but so was -NO_SEQUENCES. Will ignore sequences';
  }
  
  $self->cdna($cdna);
  $self->source($source);
  $self->aligned($aligned);
  $self->no_sequences($no_sequences);
  
  return $self;
}

=pod

=head2 clone()
  
  Description : Clones everything about the current instance except for the
                document object used which makes this a convinient way
                of resetting a Document object whilst maintaining your
                current settings
  Example     : my $new = $self->clone();
  Returntype  : Instance of PhyloXMLWriter
  Exceptions  : None
  Status      : Stable
 
=cut
 
sub clone {
  my ($self) = @_;
  my $new = $self->new();
  $new->cdna($self->cdna());
  $new->source($self->source());
  $new->aligned($self->aligned());
  $new->no_sequences($self->no_sequences());
  return $new;
}

=pod

=head2 doc()

  Description : Gives access to the document instance which contains the DOM
  representation of the trees given. A single document is reused in all
  calls so you can add trees to a single document. To add to a new document
  create a new instance of the object.
  Returntype : L<XML::LibXML::Document>
  Exceptions : None
  Status     : Stable
  
=cut

sub doc {
  my ($self) = @_;
  if(! exists $self->{doc}) {
    $self->{doc} = $self->_generate_doc();
  }
  return $self->{doc};
}

=pod

=head2 cdna()

  Arg[0] : The value to set this to
  Description : Indicates if we want CDNA sequence in the XML. If false
  the code will dump peptide data
  Returntype : Boolean
  Exceptions : None
  Status     : Stable
  
=cut

sub cdna {
  my ($self, $cdna) = @_;
  $self->{cdna} = $cdna if defined $cdna;
  return $self->{cdna};
}

=pod

=head2 no_sequences()

  Arg[0] : The value to set this to
  Description : Indicates if we do not want to perform sequence dumping 
  Returntype  : Boolean
  Exceptions  : None
  Status      : Stable
  
=cut
 
sub no_sequences {
  my ($self, $no_sequences) = @_;
  $self->{no_sequences} = $no_sequences if defined $no_sequences;
  return $self->{no_sequences};
}

=pod

=head2 source()

  Arg[0] : The value to set this to
  Description : Indicates the source of the stable identifiers for the 
                peptides.
  Returntype : String
  Exceptions : None
  Status     : Stable
  
=cut

sub source {
  my ($self, $source) = @_;
  $self->{source} = $source if defined $source;
  return $self->{source};
}

=pod

=head2 aligned()

  Arg[0] : The value to set this to
  Description : Indicates if we want to push aligned sequences into the XML
  Returntype : Boolean
  Exceptions : None
  Status     : Stable
  
=cut

sub aligned {
  my ($self, $aligned) = @_;
  $self->{aligned} = $aligned if defined $aligned;
  return $self->{aligned};
}

=pod

=head2 write_trees()

  Arg[0]      : The tree to write. Can be a single Tree or an ArrayRef
  Description : Writes a tree into the backing document representation
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the tree
  instance
  Example     : $writer->write_trees($tree);
                $writer->write_trees([$tree_one, $tree_two]);
  Status      : Stable  
  
=cut

sub write_trees {
  my ($self, $trees) = @_;
  $trees = wrap_array($trees);
  foreach my $tree (@{$trees}) {
    $self->_write_tree($tree);
  }
  return;
}

########### PRIVATE

sub _generate_doc {
  my ($self, $tree) = @_;
  
  my $doc = XML::LibXML::Document->createDocument();
  my $phyloxml = $doc->createElementNS($phylo_uri, 'phyloxml');
  $phyloxml->setNamespace($xsi_uri, 'xsi', 0);
  $phyloxml->setAttributeNS($xsi_uri, 'schemaLocation', 
    sprintf('%1$s %1$s/1.10/phyloxml.xsd', $phylo_uri));
  $doc->setDocumentElement($phyloxml);
  
  return $doc;
}

sub _write_tree {
  my ($self, $tree) = @_;
  my $root = $self->doc->documentElement();
  my $phylogeny = $self->doc->createElement('phylogeny');
  $phylogeny->setAttribute('rooted', 'true');
  $root->appendChild($phylogeny);
  
  if(check_ref($tree, 'Bio::EnsEMBL::Compara::ProteinTree')) {
    $phylogeny->setAttribute('type', 'gene tree');
    if($tree->stable_id()) {
      $phylogeny->addNewChild($phylo_uri, 'id')->appendText($tree->stable_id());
    }
  }
  
  $self->_process($tree, $phylogeny);
  $tree->release_tree();
  return;
}

sub _process {
  my ($self, $node, $parent_element) = @_;
  my @results = $self->_dispatch($node, $parent_element);
  if(@results) {
    foreach my $result (@results) {
      $parent_element->appendChild($result);
    }
  }
  return;
}

sub _dispatch {
  my ($self, $node, $parent_element) = @_;
  my $element;
  if(check_ref($node, 'Bio::EnsEMBL::Compara::AlignedMember')) {
    $element = $self->_alignedmember_processor($node, $parent_element);
  }
  elsif(check_ref($node, 'Bio::EnsEMBL::Compara::NestedSet')) {
    $element = $self->_nestedset_processor($node, $parent_element);
  }
  else {
    my $ref = ref($node);
    throw("Cannot process type $ref");
  }
  return $element;
}

###### PROCESSORS

#How we work with a basic NestedSet node
sub _nestedset_processor {
  my ($self, $node, $parent_element) = @_;
  
  my $element = $parent_element->addNewChild($phylo_uri, 'clade');
  my $dist  = $node->distance_to_parent();
  my $dup   = $node->get_tagvalue('Duplication');
  my $dubi  = $node->get_tagvalue('dubious_duplication');
  my $boot  = $node->get_tagvalue('Bootstrap');
  my $taxid = $node->get_tagvalue('taxon_id');
  my $tax   = $node->get_tagvalue('taxon_name');
  
  $element->setAttribute('branch_length', $dist) if $dist;
  
  if($boot) {
    my $confidence = $element->addNewChild($phylo_uri, 'confidence');
    $confidence->setAttribute('type', 'bootstrap');
    $confidence->appendText($boot);
  }
  
  if($taxid) {
    my $taxonomy = $element->addNewChild($phylo_uri, 'taxonomy');
    $taxonomy->addNewChild($phylo_uri, 'id')->appendText($taxid);
    $taxonomy->addNewChild($phylo_uri, 'scientific_name')->appendText($tax);
  }
  
  if($dup) {
    my $events = $element->addNewChild($phylo_uri,'events');
    my $type = $events->addNewChild($phylo_uri, 'type');
    $type->appendText('speciation_or_duplication');
    my $duplications = $events->addNewChild($phylo_uri, 'duplications');
    $duplications->appendText(1);
  }
  
  if($dubi) {
    my $dubious = $element->addNewChild($phylo_uri, 'property');
    $dubious->setAttribute('datatype', 'xsd:int');
    $dubious->setAttribute('ref', 'Compara:dubious_duplication');
    $dubious->setAttribute('applies_to', 'clade');
    $dubious->appendText($dubi);
  }
  
  if($node->get_child_count()) {
    foreach my $child (@{$node->children()}) {
      $self->_process($child, $element);
    }
  }
  
  return $element;
}

#How we supplement this with member information
sub _alignedmember_processor {
  my ($self, $protein, $parent_element) = @_;
  my $gene = $protein->gene_member();
  my $taxon = $protein->taxon();
  
  my $element = $self->_nestedset_processor($protein, $parent_element);
  
  #Stable IDs
  my $name = $element->addNewChild($phylo_uri, 'name');
  $name->appendText($gene->stable_id());
  
  #Taxon
  my $taxonomy = $element->addNewChild($phylo_uri, 'taxonomy');
  $taxonomy->addNewChild($phylo_uri, 'id')->appendText($taxon->taxon_id());
  $taxonomy->addNewChild($phylo_uri, 'scientific_name')->appendText($taxon->name());
  
  #Dealing with Sequence
  my $sequence = $element->addNewChild($phylo_uri, 'sequence');
  my $accession = $sequence->addNewChild($phylo_uri, 'accession');
  $accession->setAttribute('source', $self->source());
  $accession->appendText($protein->stable_id());
  $sequence->addNewChild($phylo_uri, 'name')->appendText($protein->display_label()) if $protein->display_label();
  my $location = sprintf('%s:%d-%d',$gene->chr_name(), $gene->chr_start(), $gene->chr_end());
  $sequence->addNewChild($phylo_uri, 'location')->appendText($location);
  
  if(!$self->no_sequences()) {
    my $mol_seq;
    if($self->aligned()) {
      $mol_seq = ($self->cdna()) ? $protein->cdna_alignment_string() : $protein->alignment_string();
    }
    else {
      $mol_seq = ($self->cdna()) ? $protein->sequence_cds() : $protein->sequence(); 
    }
    $mol_seq =~ s/\s+//g if $self->cdna();
    
    my $mol_seq_element = $sequence->addNewChild($phylo_uri, 'mol_seq');
    $mol_seq_element->setAttribute('is_aligned', $self->aligned() || 0);
    $mol_seq_element->appendText($mol_seq);
  }
  
  #Adding GenomeDB
  my $genome_db_property = $element->addNewChild($phylo_uri, 'property');
  $genome_db_property->setAttribute('datatype', 'xsd:string');
  $genome_db_property->setAttribute('ref', 'Compara:genome_db_name');
  $genome_db_property->setAttribute('applies_to', 'clade');
  $genome_db_property->appendText($protein->genome_db()->name());

  return $element;
}

1;