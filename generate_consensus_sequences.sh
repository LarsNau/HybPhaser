#!/bin/bash
############


set +e
set -u
set -o pipefail

CONTIG="normal"
THREADS=1
SAMPLE=""
ALLELE_FREQ=0.15
READ_DEPTH=10
ALLELE_COUNT=4
BASE_FOLDER="./"

while getopts 'st:n:a:f:d:p:' OPTION; do
  case "$OPTION" in

    s)
      echo "supercontig"
      CONTIG="SC"
      ;;

    t)
      THREADS=$OPTARG
     ;;
    
    n)
    echo "name of sample=$OPTARG"
      SAMPLE=$OPTARG
     ;;
	 
    f)
      ALLELE_FREQ=$OPTARG
     ;;
    
    a)
      ALLELE_COUNT=$OPTARG
     ;;
    
    d)
      READ_DEPTH=$OPTARG
     ;;
    
    p)
      BASE_FOLDER=$OPTARG
     ;;         
    
    ?)
      echo "This script is used to generate consensus sequences by remapping reads to de novo contigs generated by HybPiper. It is part of the HybPhaser workflow and has to be executed first. 
      
      Usage: generate_consensus_sequences.sh [options]
      
        Options:
        
        General:
      
            -n  Name of sample (required)
        
            -p  Path to HybPiper results folder. Default is current folder.
        
            -t  Maximum number of threads used. Default is 1.
            
            -s (without argument) If chosen, supercontigs are used instead of normal contigs. 
        
        Adjust consensus sequence generation:
        
            -d  Minimum coverage on site to be regarded for assigning ambiguity code.
                If read depth on that site is lower than chosen value, the site is not used for ambiguity code but the most frequent base is returned. Default is 10.
            
            -f  Minimum allele frequency regarded for assigning ambiguity code.
                If the alternative allele is less frequent than the chosen value, it is not included in ambiguity coding. Default is 0.15.
            
            -a  Minimum count of alleles to be regarded for assigning ambiguity code.
                If the alternative allele ocurrs less often than the chosen value, it is not included in ambiguity coding. Default is 4.
        " >&2
        
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

cd $BASE_FOLDER$SAMPLE
  for DIR in */
    do
    if [ -d "$DIR$SAMPLE" ]; then
            
      GENE=${DIR/\//}
      OUTDIR=$DIR$SAMPLE/remapping/
      OUTDIRCONSENSUS=$DIR$SAMPLE/sequences/remapping/

      # checking for paired-end reads
      if [ -f $DIR$GENE"_interleaved.fasta" ];then
        READS=$DIR$GENE"_interleaved.fasta"
        READTYPE="PE"
      else 
         READS=$DIR$GENE"_unpaired.fasta"
         READTYPE="SE"
      fi 
      
      if [ $CONTIG = 'SC'  ];then
       SC="_supercontig"
       REFFILE=$DIR$SAMPLE/sequences/intron/$GENE"_supercontig.fasta"
       OUTFILECONSENSUS=$OUTDIRCONSENSUS$GENE$"_supercontig-consensus.fasta"
       REF=$OUTDIR$GENE$SC".fasta"
      else 
       SC=""
       REFFILE=$DIR$SAMPLE/sequences/FNA/$GENE".FNA"
       OUTFILECONSENSUS=$OUTDIRCONSENSUS$GENE$"_consensus.fasta"
       REF=$OUTDIR$GENE".FNA"
      fi 


      BAM=$OUTDIR$GENE$SC"_remapped.bam"
      VCFZ=$OUTDIR$GENE$SC"_remapped.vcf.gz"

      mkdir -p $OUTDIR
      mkdir -p $OUTDIRCONSENSUS
      if [ -f "$REFFILE" ]; then
      
              
        bwa index $REFFILE
      
        if [ "$READTYPE" = "SE" ];then 
          bwa mem $REFFILE $READS -t $THREADS | samtools sort > $BAM
        else 
          bwa mem -p $REFFILE $READS -t $THREADS | samtools sort > $BAM
        fi
      
        bcftools mpileup -I -Ov -f $REFFILE $BAM | bcftools call -mv -A -Oz -o $VCFZ
        bcftools index -f $VCFZ
        bcftools consensus -I -i "(DP4[2]+DP4[3])/(DP4[0]+DP4[1]+DP4[2]+DP4[3]) >= $ALLELE_FREQ && (DP4[0]+DP4[1]+DP4[2]+DP4[3]) >= $READ_DEPTH && (DP4[2]+DP4[3]) >= $ALLELE_COUNT " -f $REFFILE $VCFZ | awk '{if(NR==1) {print $0} else {if($0 ~ /^>/) {print "\n"$0} else {printf $0}}}' > $OUTFILECONSENSUS
        echo "" >> $OUTFILECONSENSUS
#       rm $REFFILE.*
        rm $VCFZ".csi"
        if [ "$CONTIG" != "s" ];then 
          sed -i "s/>.*/>${SAMPLE///}-$GENE/" $OUTFILECONSENSUS
        fi
      else 
        echo $REFFILE does not exist!
      fi
      
    else 
    echo $DIR$SAMPLE does not exist
    fi
    done
 cd ..
