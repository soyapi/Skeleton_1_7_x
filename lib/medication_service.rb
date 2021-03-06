module MedicationService

	def self.arv(drug)
		arv_drugs.map(&:concept_id).include?(drug.concept_id)
	end

	def self.arv_drugs
		arv_concept       = ConceptName.find_by_name("ANTIRETROVIRAL DRUGS").concept_id
		arv_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', arv_concept])
		arv_drug_concepts
	end

	def self.tb_medication(drug)
		tb_drugs.map(&:concept_id).include?(drug.concept_id)
	end

	def self.tb_drugs
		tb_medication_concept       = ConceptName.find_by_name("Tuberculosis treatment drugs").concept_id
		tb_medication_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', tb_medication_concept])
		tb_medication_drug_concepts
	end
	
	def self.diabetes_medication(drug)
		diabetes_drugs.map(&:concept_id).include?(drug.concept_id)
	end	
	
	def self.diabetes_drugs
		diabetes_medication_concept       = ConceptName.find_by_name("DIABETES MEDICATION").concept_id
		diabetes_medication_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', diabetes_medication_concept])
		diabetes_medication_drug_concepts
	end

  # Generate a given list of Regimen+s for the given +Patient+ <tt>weight</tt>
  # into select options. 
	def self.regimen_options(weight, program)
		regimens = Regimen.find(	:all,
									:order => 'regimen_index',
									:conditions => ['? >= min_weight AND ? < max_weight AND program_id = ?', weight, weight, program.program_id])

		options = regimens.map { |r|
			concept_name = (r.concept.concept_names.typed("SHORT").first ||	r.concept.concept_names.typed("FULLY_SPECIFIED").first).name
			if r.regimen_index.blank?
				["#{concept_name}", r.concept_id, r.regimen_index.to_i]
			else
				["#{r.regimen_index} - #{concept_name}", r.concept_id, r.regimen_index.to_i]
			end
		}.sort_by{| r | r[2]}.uniq

		return options
	end
	
  def self.current_orders(patient)
    encounter = current_treatment_encounter(patient)
    orders = encounter.orders.active
    orders
  end
  
  def self.current_treatment_encounter(patient)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.current.find_by_encounter_type(type.id)
    encounter ||= patient.encounters.create(:encounter_type => type.id)
  end

  def self.generic
    #tag_id = ConceptNameTag.find_by_tag("preferred_qech_aetc_opd").concept_name_tag_id
 
 		medication_tag = CoreService.get_global_property_value("application_generic_medication")
 			   
    all_drugs = Drug.all.collect {|drug|
      # [Concept.find(drug.concept_id).name.name, drug.concept_id] rescue nil

      [(drug.concept.fullname rescue drug.concept.shortname rescue ' '), drug.concept_id]
      #[ConceptName.find(:last, :conditions => ["concept_id = ? AND voided = 0 AND concept_name_id IN (?)", 
      #      drug.concept_id, ConceptNameTagMap.find(:all, :conditions => ["concept_name_tag_id = ?", tag_id]).collect{|c| 
      #        c.concept_name_id}]).name, drug.concept_id] rescue nil
    
    }.compact.uniq  rescue []
    
    if !medication_tag.blank?
    	application_drugs = concept_set(medication_tag)
    else
    	application_drugs = all_drugs
    end
    return_drugs = all_drugs - (all_drugs - application_drugs) 
  end

  def self.frequencies
    ConceptName.find_by_sql("SELECT name FROM concept_name WHERE concept_id IN \
                        (SELECT answer_concept FROM concept_answer c WHERE \
                        concept_id = (SELECT concept_id FROM concept_name \
                        WHERE name = 'DRUG FREQUENCY CODED')) AND concept_name_id \
                        IN (SELECT concept_name_id FROM concept_name_tag_map \
                        WHERE concept_name_tag_id = (SELECT concept_name_tag_id \
                        FROM concept_name_tag WHERE tag = 'preferred_dmht'))").collect {|freq|
                            freq.name rescue nil
                        }.compact rescue []
  end
  
	def self.fully_specified_frequencies
		concept_id = ConceptName.find_by_name('DRUG FREQUENCY CODED').concept_id
		set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
		frequencies = []
		options = set.each{ | item | 
			next if item.concept.blank?
			frequencies << [item.concept.shortname, item.concept.fullname + "(" + item.concept.shortname + ")"]
		}
		frequencies
	end
  
	def self.dosages(generic_drug_concept_id)    
		Drug.find(:all, :conditions => ["concept_id = ?", generic_drug_concept_id]).collect {|d|
			["#{d.name.upcase rescue ""}", "#{d.dose_strength.to_f rescue 1}", "#{d.units.upcase rescue ""}"]
		}.uniq.compact rescue []
	end
	
  def self.concept_set(concept_name)
    concept_id = ConceptName.find(:first, :conditions =>["name = ?", concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.concept_id] }
    return options
  end
end
