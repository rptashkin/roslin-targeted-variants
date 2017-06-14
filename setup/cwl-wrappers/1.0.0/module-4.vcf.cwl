#!/usr/bin/env cwl-runner

$namespaces:
  dct: http://purl.org/dc/terms/
  foaf: http://xmlns.com/foaf/0.1/
  doap: http://usefulinc.com/ns/doap#

$schemas:
- http://dublincore.org/2012/06/14/dcterms.rdf
- http://xmlns.com/foaf/spec/20140114.rdf
- http://usefulinc.com/ns/doap#

doap:name: module-4.cwl
doap:release:
- class: doap:Version
  doap:revision: 1.0.0

dct:creator:
- class: foaf:Organization
  foaf:name: Memorial Sloan Kettering Cancer Center
  foaf:member:
  - class: foaf:Person
    foaf:name: Jaeyoung Chun
    foaf:mbox: mailto:chunj@mskcc.org

dct:contributor:
- class: foaf:Organization
  foaf:name: Memorial Sloan Kettering Cancer Center
  foaf:member:
  - class: foaf:Person
    foaf:name: Jaeyoung Chun
    foaf:mbox: mailto:chunj@mskcc.org

cwlVersion: v1.0

class: Workflow
requirements:
    MultipleInputFeatureRequirement: {}
    ScatterFeatureRequirement: {}
    SubworkflowFeatureRequirement: {}
    InlineJavascriptRequirement: {}
    StepInputExpressionRequirement: {}

inputs:

    bams:
        type:
            type: array
            items: File
        secondaryFiles:
            - ^.bai

    mutect_vcf:
        type: File
    mutect_callstats:
        type: File
    vardict_vcf:
        type: File
    sid_vcf:
        type: File
    sid_verbose:
        type: File
    pindel_vcf:
        type: File

    tumor_sample_name: string
    normal_sample_name: string

    genome: string

outputs:

    filtering_sid_vcf:
        type: File
        outputSource: filtering/sid_vcf
    filtering_mutect_vcf:
        type: File
        outputSource: filtering/mutect_vcf
    filtering_vardict_vcf:
        type: File
        outputSource: filtering/vardict_vcf
    filtering_pindel_vcf:
        type: File
        outputSource: filtering/pindel_vcf

    sid_vcf:
        type: File
        outputSource: normalize/sid_vcf
    mutect_vcf:
        type: File
        outputSource: normalize/mutect_vcf
    vardict_vcf:
        type: File
        outputSource: normalize/vardict_vcf
    pindel_vcf:
        type: File
        outputSource: normalize/pindel_vcf

    combined_vcf:
        type: File
        outputSource: combine/out_vcf

steps:

    filtering:
        in:
            mutect_vcf: mutect_vcf
            mutect_callstats: mutect_callstats
            vardict_vcf: vardict_vcf
            sid_vcf: sid_vcf
            sid_verbose: sid_verbose
            pindel_vcf: pindel_vcf
            tumor_sample_name: tumor_sample_name
        out: [vardict_vcf, sid_vcf, pindel_vcf, mutect_vcf]
        run:
            class: Workflow
            inputs:
                mutect_vcf: File
                mutect_callstats: File
                vardict_vcf: File
                sid_vcf: File
                sid_verbose: File
                pindel_vcf: File
                tumor_sample_name: string
            outputs:
                sid_vcf:
                    type: File
                    outputSource: sid/vcf
                mutect_vcf:
                    type: File
                    outputSource: mutect/vcf
                vardict_vcf:
                    type: File
                    outputSource: vardict/vcf
                pindel_vcf:
                    type: File
                    outputSource: pindel/vcf
            steps:
                mutect:
                    run: basic-filtering.mutect/0.1.6/basic-filtering.mutect.cwl
                    in:
                        inputVcf: mutect_vcf
                        inputTxt: mutect_callstats
                        tsampleName: tumor_sample_name
                    out: [vcf]
                pindel:
                    run: basic-filtering.pindel/0.1.6/basic-filtering.pindel.cwl
                    in:
                        inputVcf: pindel_vcf
                        tsampleName: tumor_sample_name
                    out: [vcf]
                sid:
                    run: basic-filtering.somaticIndelDetector/0.1.6/basic-filtering.somaticIndelDetector.cwl
                    in:
                        inputVcf: sid_vcf
                        inputTxt: sid_verbose
                        tsampleName: tumor_sample_name
                    out: [vcf]
                vardict:
                    run: basic-filtering.vardict/0.1.6/basic-filtering.vardict.cwl
                    in:
                        inputVcf: vardict_vcf
                        tsampleName: tumor_sample_name
                    out: [vcf]

    normalize:
        in:
            mutect_vcf: filtering/mutect_vcf
            vardict_vcf: filtering/vardict_vcf
            sid_vcf: filtering/sid_vcf
            pindel_vcf: filtering/pindel_vcf
            genome: genome
        out: [vardict_vcf, sid_vcf, pindel_vcf, mutect_vcf]
        run:
            class: Workflow
            inputs:
                mutect_vcf: File
                vardict_vcf: File
                sid_vcf: File
                pindel_vcf: File
                genome: string
            outputs:
                sid_vcf:
                    type: File
                    outputSource: sid/vcf
                mutect_vcf:
                    type: File
                    outputSource: mutect/vcf
                vardict_vcf:
                    type: File
                    outputSource: vardict/vcf
                pindel_vcf:
                    type: File
                    outputSource: pindel/vcf
            steps:
                mutect:
                    run: cmo-bcftools.norm/1.3.1/cmo-bcftools.norm.cwl
                    in:
                        vcf: mutect_vcf
                        output:
                            default: "mutect-norm.vcf"
                        output_type:
                            default: "v"
                        fasta_ref: genome
                    out: [vcf]
                pindel:
                    run: cmo-bcftools.norm/1.3.1/cmo-bcftools.norm.cwl
                    in:
                        vcf: pindel_vcf
                        output:
                            default: "pindel-norm.vcf"
                        output_type:
                            default: "v"
                        fasta_ref: genome
                    out: [vcf]
                sid:
                    run: cmo-bcftools.norm/1.3.1/cmo-bcftools.norm.cwl
                    in:
                        vcf: sid_vcf
                        output:
                            default: "sid-norm.vcf"
                        output_type:
                            default: "v"
                        fasta_ref: genome
                    out: [vcf]
                vardict:
                    run: cmo-bcftools.norm/1.3.1/cmo-bcftools.norm.cwl
                    in:
                        vcf: vardict_vcf
                        output:
                            default: "vardict-norm.vcf"
                        output_type:
                            default: "v"
                        fasta_ref: genome
                    out: [vcf]

    combine:
        run: cmo-gatk.CombineVariants/3.3-0/cmo-gatk.CombineVariants.cwl
        in:
            variants_mutect: normalize/mutect_vcf
            variants_vardict: normalize/vardict_vcf
            variants_sid: normalize/sid_vcf
            variants_pindel: normalize/pindel_vcf
            unsafe:
                default: "ALLOW_SEQ_DICT_INCOMPATIBILITY"
            genotypemergeoption:
                default: "PRIORITIZE"
            rod_priority_list:
                default: ["VarDict", "MuTect", "SomaticIndelDetector", "Pindel"]
            reference_sequence: genome
            tumor_sample_name: tumor_sample_name
            out:
                valueFrom: ${ return inputs.tumor_sample_name + ".combined-variants.vcf" }
        out: [out_vcf]