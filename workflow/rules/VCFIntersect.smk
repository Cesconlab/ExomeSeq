rule vcfIntersectINDEL:
  input:
    var_vcf="results/Varscan/snv/{sample}/{sample}.indel.Somatic.hc.vcf",
    mut2_vcf="results/MuTect2Merge/{sample}/{sample}.indels.recode.vcf",
    strelka_vcf="results/Strelka/{sample}/{sample}.myAnalysis/results/variants/{sample}_Slk_somatic.indels.vcf.gz",
    ref = 'ref/genome.fa',
    sequenza="results/Sequenza/{sample}.gz"
  params:
    outdir="results/vcfIntersect",
    script= "scripts/vcfIntersect.sh",
    samp="{sample}"
  output:
    #bash_indel="results/vcfIntersect/bash_scripts/{sample}_Indel_overlap.sh",
    vcf_file="results/vcfIntersect/indels/{sample}/{indel}.vcf",
  shell:
    """
    sh {params.script} \
    {params.outdir}/indels \
    {params.samp} \
    {params.samp} \
    {input.var_vcf} \
    {input.mut2_vcf} \
    {input.strelka_vcf}
    """
rule vcfIntersectSNV:
  input:
    var_vcf="results/Varscan/snv/{sample}/{sample}.snp.Somatic.hc.vcf",
    mut2_vcf="results/MuTect2Merge/{sample}/{sample}.snvs.recode.vcf",
    strelka_vcf="results/Strelka/{sample}/{sample}.myAnalysis/results/variants/{sample}_Slk_somatic.snvs.vcf.gz",
    mut1_vcf="results/MuTect1/{sample}/{sample}.mut1.vcf",
    ref = 'ref/genome.fa',
  params:
    outdir="results/vcfIntersect",
    script= "scripts/vcfIntersect.sh",
    samp="{sample}"
  output:
    #bash_snv="results/vcfIntersect/bash_scripts/{sample}_snvs_overlap.sh",
    vcf_file="results/vcfIntersect/snvs/{sample}/{snv}.vcf",
  shell:
    """
    sh {params.script} \
    {params.outdir}/snvs \
    {params.samp} \
    {params.samp} \
    {input.mut1_vcf} \
    {input.var_vcf} \
    {input.mut2_vcf} \
    {input.strelka_vcf}
    """
