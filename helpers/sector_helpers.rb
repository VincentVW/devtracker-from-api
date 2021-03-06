module SectorHelpers


	def high_level_sectors_structure
=begin
		sectors = @cms_db['sector-hierarchies'].aggregate([{ 
				"$group" => { 
				"_id"  => "$highLevelCode",
				"name" => {
					"$first" => "$highLevelName"
				}, 
				"sectorCodes" => {
					"$addToSet" => "$sectorCode"
				} 
			}
		}]).map { |l| {
			:code   => l['_id'],
			:name   => l['name'],
			:budget => calculate_total_sector_level_budget(l['sectorCodes'])
		}}

		calculate_hierarchy_structure(sectors)
=end		
	end
	

	def high_level_sector_list
		
	#	highLevelSector = JSON.parse(File.read('data/sector_hierarchies.json'))
		
		sectorValuesJSON = RestClient.get "http://dfid-oipa.zz-clients.net/api/activities/aggregations?reporting_organisation=GB-1&group_by=sector&aggregations=budget&order_by=-budget&format=json"
  		sectorValues  = JSON.parse(sectorValuesJSON)

  		highLevelSector = JSON.parse(File.read('data/test_sh.json'))
  	#	sectorValues  = JSON.parse(File.read('data/test_budget.json'))


		highLevelSector.map do |elem| 
	       {  
	       	  :code          => elem["High Level Code (L1)"],
	          :name          => elem["High Level Sector Description"],
			  :budget 		  => sectorValues.select do |source|
                         			source["sector"]["code"] == elem["Code (L3)"].to_s 
                      			end.map{|elem|elem["budget"]}.inject(:+)	                            

	       } 
		end

	end


	def sector_categories_structure(highLevelSectorCode)

		sectors = @cms_db['sector-hierarchies'].aggregate([{
			"$match" => {
				"highLevelCode" => highLevelSectorCode
			}			
		},{ 
			"$group" => { 
				"_id"  => "$categoryCode",
				"name" => {
					"$first" => "$categoryName"
				}, 
				"sectorCodes" => {
					"$addToSet" => "$sectorCode"
				} 
			} 
		}]).map { |l| {
			:code   => l['_id'],
			:name   => l['name'],
			:budget => calculate_total_sector_level_budget(l['sectorCodes'])
		}}

		calculate_hierarchy_structure(sectors)
	end

	def sectors_structure(categoryCode)		
 		sectors = @cms_db['sector-hierarchies'].find({
			"categoryCode" => categoryCode
		}).map { |l| {
			:code   => l['sectorCode'],
			:name   => l['sectorName'],
			:budget => calculate_total_sector_level_budget([ l['sectorCode'] ])
		}}

		calculate_hierarchy_structure(sectors)
	end

	def retrieve_project_name(projectIatiId)
		result = @cms_db['projects'].find({
			'iatiId' => projectIatiId
		})
		((result.first || { 'title' => projectIatiId })['title'])
	end

	def calculate_hierarchy_structure(sectors)
		totalSectorsBudget = Float(sectors.map { |s| s[:budget] }.inject(:+))
		maxBudget = Float(sectors.max_by { |s| s[:budget] }[:budget])

		sectors.sort_by { |s| s[:name] }.map { |s| s.merge({
			:percentage => s[:budget] / totalSectorsBudget * 100.0,
			:cellWidth	=> s[:budget] / maxBudget * 60.0
		})}.select { |s| s[:percentage] >= 0.01 }
	end		

	def calculate_total_sector_level_budget(sectorCodes)
		result = @cms_db['project-sector-budgets'].aggregate([
			{
				"$match" => {
					"sectorCode" => {
						"$in" => sectorCodes
					},
					"date" => {
						"$gte" => "#{financial_year}-04-01",
						"$lte" => "#{financial_year + 1}-03-31"
					}
				}
			}, {
				"$group" => {
					"_id" => nil, 
					"total" => {
						"$sum" => "$sectorBudget"}
				}
			}
		])
		(result.first || { 'total' => 0 })['total']
	end

	def retrieve_high_level_sector_names(projectIatiId)
		sectorCodes = @cms_db['project-sector-budgets'].find({
			"projectIatiId" => projectIatiId
		}).map { |s| s['sectorCode'] }.to_a

		sectorNames = @cms_db['sector-hierarchies'].find({
			"sectorCode" => {"$in" => sectorCodes}
		}).map { |s| s['highLevelName'] }.to_a.uniq.join('#')
	end
end
