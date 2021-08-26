
rule mapFASTQ:
  input:
    f1 =  get_r1,
    f2 =  get_r2,
    ref = '/cluster/tools/data/genomes/human/hg19/iGenomes/Sequence/BWAIndex/genome.fa'
  params:
    runtime="72:00:00"
  output: temp("{output_dir}/alignment/{sample}/{sample}.sam")
  threads: 4
  conda:
    "../envs/bwa.yaml",
  resources: mem_mb=12000
  shell:
    """
    bwa mem -p -t4 -R "@RG\\tID:{wildcards.sample}\\tLB:Exome\\tSM:{wildcards.sample}\\tPL:ILLUMINA" {input.ref} {input.f1} {input.f2} > {output}
    """
rule samtoolsSORT:
  input: "{output_dir}/alignment/{sample}/{sample}.sam"
  params:
    runtime="5:00:00"
  output: "{output_dir}/alignment/{sample}/{sample}_sorted.bam"
  threads: 4
  conda:
    "../envs/bwa.yaml",
  resources: mem_mb=8000
  shell:
    """
    samtools sort -@4 {input} > {output}
    """

rule samtoolsINDEX:
  input: "{output_dir}/alignment/{sample}/{sample}_sorted.bam"
  params:
    runtime="5:00:00"
  output: "{output_dir}/alignment/{sample}/{sample}_sorted.bam.bai"
  threads: 2
  conda:
    "../envs/bwa.yaml",
  resources: mem_mb=8000
  shell:
    """
    samtools index {input} > {output}
    """

rule picardMarkDuplicates:
  input:
    bam="{output_dir}/alignment/{sample}/{sample}_sorted.bam",
    bai="{output_dir}/alignment/{sample}/{sample}_sorted.bam.bai",
  params:
  runtime="24:00:00"
  output:
    dedup="{output_dir}/alignment/{sample}/{sample}_sorted.dedup.bam",
    metrics="{output_dir}/alignment/{sample}/{sample}_picardmetrics.txt"
  threads: 4
  conda:
    "../envs/bwa.yaml",
  resources: mem_mb=20000
  shell:
    """
    java -Xmx12g -jar $picard_dir/picard.jar MarkDuplicates INPUT={input.bam} OUTPUT={output.dedup} METRICS_FILE={output.metrics} ASSUME_SORTED=true MAX_RECORDS_IN_RAM=100000 VALIDATION_STRINGENCY=SILENT CREATE_INDEX=true USE_JDK_DEFLATER=true USE_JDK_INFLATER=true
    """
rule gatkRealignerTargetCreator:
  input:
    bam="{output_dir}/alignment/{sample}/{sample}_sorted.dedup.bam",
    ref= '/cluster/tools/data/genomes/human/hg19/iGenomes/Sequence/WholeGenomeFasta/genome.fa',
    region=region,
    known1=known_mills,
    known2=known_1000G,
  params:
    runtime="24:00:00"
  output: "{output_dir}/alignment/{sample}/{sample}.IndelRealigner.intervals"
  threads: 4
  conda:
    "../envs/gatk.yaml",
  resources: mem_mb=8000
  shell:
    """
    java -Xmx8g -jar $gatk_dir/GenomeAnalysisTK.jar -T RealignerTargetCreator \
    --disable_auto_index_creation_and_locking_when_reading_rods \
    -nt 4 \
    -I {input.bam} \
    -R {input.ref} \
    --intervals {input.region} \
    --interval_padding 100 \
    -known {input.known1} \
    -known {input.known2} \
    -dt None \
    -o {output}
    """

rule gatkIndelRealigner:
  input:
    bam="{output_dir}/alignment/{sample}/{sample}_sorted.dedup.bam",
    ref= '/cluster/tools/data/genomes/human/hg19/iGenomes/Sequence/WholeGenomeFasta/genome.fa',
    interval="{output_dir}/alignment/{sample}/{sample}.IndelRealigner.intervals",
    known1=known_mills,
    known2=known_1000G,
  params:
    runtime="24:00:00"
  output: "{output_dir}/alignment/{sample}/{sample}.realigned.bam"
  threads: 2
  conda:
    "../envs/gatk.yaml",
  resources: mem_mb=12000
  shell:
    """
    java -Xmx12g -jar $gatk_dir/GenomeAnalysisTK.jar \
    --disable_auto_index_creation_and_locking_when_reading_rods \
    -T IndelRealigner \
    -I {input.bam} \
    -o {output} \
    -R {input.ref} \
    -targetIntervals {input.interval} \
    -known {input.known1} \
    -known {input.known2} \
    -dt None \
    -compress 0
    """

rule gatkBaseRecalibrator:
  input:
    bam="{output_dir}/alignment/{sample}/{sample}.realigned.bam",
    ref= '/cluster/tools/data/genomes/human/hg19/iGenomes/Sequence/WholeGenomeFasta/genome.fa',
    dbsnp=dbsnp,
    region=region,
  params:
    runtime="24:00:00"
  output: "{output_dir}/alignment/{sample}/{sample}.recal_data.grp"
  threads: 4
  conda:
    "../envs/gatk.yaml",
  resources: mem_mb=18000
  shell:
    """
    java -Xmx18g -jar $gatk_dir/GenomeAnalysisTK.jar \
    -T BaseRecalibrator \
    -nct 4 \
    --disable_auto_index_creation_and_locking_when_reading_rods \
    -I {input.bam} \
    -o {output} \
    -R {input.ref} \
    -knownSites {input.dbsnp} \
    -knownSites {input.region} \
    -rf BadCigar \
    -cov ReadGroupCovariate \
    -cov ContextCovariate \
    -cov CycleCovariate \
    -cov QualityScoreCovariate \
    -dt None
    """
rule gatkPrintReads:
  input:
    bam="{output_dir}/alignment/{sample}/{sample}.realigned.bam",
    ref= '/cluster/tools/data/genomes/human/hg19/iGenomes/Sequence/WholeGenomeFasta/genome.fa',
    recal="{output_dir}/alignment/{sample}/{sample}.recal_data.grp"
  params:
    runtime="24:00:00"
  output: "{output_dir}/alignment/{sample}/{sample}.realigned.recal.bam"
  threads: 4
  conda:
    "../envs/gatk.yaml",
  resources: mem_mb=18000
  shell:
    """
    java -Xmx18g -jar $gatk_dir/GenomeAnalysisTK.jar \
    -T PrintReads \
    --disable_auto_index_creation_and_locking_when_reading_rods \
    -nct 4 \
    -I {input.bam} \
    -o {output} \
    -R {input.ref} \
    -BQSR {input.recal} \
    -rf BadCigar \
    -dt None
    """