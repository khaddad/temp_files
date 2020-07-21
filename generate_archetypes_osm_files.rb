# utility to generate a series of archetype building based on an NECB vintage. The locations for the archetypes can be specified in method 'get_loc_list'.
# The building types can be specified in array 'building_types' in the main program section.
# status:
#   -the script generates the archetype osm files correctly and then runs the annual simulations
#   -when the openstudio file is run there is a modification to the list of output variables in the osm/idf file. It is not clear why the change takes place.
#    When the osm file is scanned before the annual run, no output variables are found. The final idf file inside the 'run' folder has several output variables
#    specified. The run is being executed using the cli facility. There must be then an input file to the cli that controls the run of the cli and modifies
#    the output variables in the process.

require 'c:/openstudio-standards/test/helpers/minitest_helper'
require 'c:/openstudio-standards/test/helpers/create_doe_prototype_helper'
require 'c:/openstudio-standards/test/helpers/compare_models_helper'
#require_relative '../necb/regression_helper'

# list of weather files
def get_loc_list
  loc_list = {}
  loc_list['QC'] = [
  'CAN_QC_Montreal-Trudeau.Intl.AP.716270_CWEC2016.epw'
  ]
=begin
   loc_list['BC'] = [
  'CAN_BC_Vancouver.Intl.AP.718920_CWEC2016.epw'
  ]
  
  loc_list['ON'] = [
  'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  ]  

  loc_list['NS'] = [
  'CAN_NS_Halifax.Dockyard.713280_CWEC2016.epw'
  ]

  loc_list['QC'] = [
  'CAN_QC_Montreal-Trudeau.Intl.AP.716270_CWEC2016.epw'
  ]
  
  loc_list['PE'] = [
  'CAN_PE_Charlottetown.AP.717060_CWEC2016.epw'
  ]

  loc_list["NB"] = [
  'CAN_NB_Fredericton.Intl.AP.717000_CWEC2016.epw'
  ]
 
  loc_list['NF'] = [
  'CAN_NL_St.Johns.Intl.AP.718010_CWEC2016.epw'
  ]  
  
  loc_list['AB'] = [
  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
  ]

  loc_list['MB'] = [
  'CAN_MB_Winnipeg-Richardson.Intl.AP.718520_CWEC2016.epw'
  ]

  loc_list['SK'] = [
  'CAN_SK_Regina.Intl.AP.715140_CWEC2016.epw'
  ]

  loc_list['NT']  = [
  'CAN_NT_Yellowknife.AP.719360_CWEC2016.epw'
  ]
=end
  return loc_list
end

# method to create prototype models
def create_model_and_regression_test(epw_file:,
                                     template:,
                                     building_type:,
									 primary_heating_fuel:
                                    )
  test_dir = "#{File.dirname(__FILE__)}/output"
  if !Dir.exists?(test_dir) then Dir.mkdir(test_dir) end
  model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}"
  run_dir = "#{test_dir}/#{model_name}"
  if !Dir.exists?(run_dir) then Dir.mkdir(run_dir) end
  model = Standard.build("#{template}").model_create_prototype_model( epw_file: epw_file,
                                                                      sizing_run_dir: run_dir,
                                                                      template: template,
                                                                      building_type: building_type,
																	  primary_heating_fuel: primary_heating_fuel)
  unless model.instance_of?( OpenStudio::Model::Model )
    puts "Creation of Model for #{osm_model_path} failed. Please check output for errors."
  end
  #Save osm file.
  filename = "#{File.dirname(__FILE__)}/run_osm_files/#{model_name}.osm"
  FileUtils.mkdir_p(File.dirname(filename))
  File.delete(filename) if File.exist?(filename)
  puts "Saving osm file to : #{filename}"
  model.save(filename)
  return model,run_dir
end


# Get the full path to the weather file that is specified in the model.
#
# @return [OpenStudio::OptionalPath]
def model_get_full_weather_file_path(model)
  full_epw_path = OpenStudio::OptionalPath.new

  if model.weatherFile.is_initialized
    epw_path = model.weatherFile.get.path
    if epw_path.is_initialized
      if File.exist?(epw_path.get.to_s)
        full_epw_path = OpenStudio::OptionalPath.new(epw_path.get)
      else
        # If this is an always-run Measure, need to check a different path
        alt_weath_path = File.expand_path(File.join(Dir.pwd, '../../resources'))
        alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
        if File.exist?(alt_epw_path)
          full_epw_path = OpenStudio::OptionalPath.new(OpenStudio::Path.new(alt_epw_path))
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
        end
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has a weather file assigned, but the weather file path has been deleted.')
    end
  else
    OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has not been assigned a weather file.')
  end

  return full_epw_path
end

# run annual simulation
def model_run_simulation_and_log_errors(model, run_dir = "#{Dir.pwd}/Run")
  # Make the directory if it doesn't exist
  unless Dir.exist?(run_dir)
    FileUtils.mkdir_p(run_dir)
  end

  # Save the model to energyplus idf
  idf_name = 'in.idf'
  osm_name = 'in.osm'
  osw_name = 'in.osw'
  OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', "Starting simulation here: #{run_dir}.")
  OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Running simulation #{run_dir}.")
  forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
  idf = forward_translator.translateModel(model)
  idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")
  osm_path = OpenStudio::Path.new("#{run_dir}/#{osm_name}")
  osw_path = OpenStudio::Path.new("#{run_dir}/#{osw_name}")
  idf.save(idf_path, true)
  model.save(osm_path, true)

  # Set up the simulation
  # Find the weather file
  epw_path = model_get_full_weather_file_path(model)
  if epw_path.empty? then return false end
  epw_path = epw_path.get

  # close current sql file
  model.resetSqlFile

  # If running on a regular desktop, use RunManager.
  # If running on OpenStudio Server, use WorkFlowMananger
  # to avoid slowdown from the run.
  use_runmanager = true

  begin
    workflow = OpenStudio::WorkflowJSON.new
    use_runmanager = false
  rescue NameError
    use_runmanager = true
  end

  sql_path = nil
  if use_runmanager
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Running with RunManager.')

    # Find EnergyPlus
    ep_dir = OpenStudio.getEnergyPlusDirectory
    ep_path = OpenStudio.getEnergyPlusExecutable
    ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
    idd_path = OpenStudio::Path.new(ep_dir.to_s + '/Energy+.idd')
    output_path = OpenStudio::Path.new("#{run_dir}/")

    # Make a run manager and queue up the run
    run_manager_db_path = OpenStudio::Path.new("#{run_dir}/run.db")
    # HACK: workaround for Mac with Qt 5.4, need to address in the future.
    OpenStudio::Application.instance.application(false)
    run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
    job = OpenStudio::Runmanager::JobFactory.createEnergyPlusJob(ep_tool,
                                                                   idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)

    run_manager.enqueue(job, true)

    # Start the run and wait for it to finish.
    while run_manager.workPending
      sleep 1
      OpenStudio::Application.instance.processEvents
    end

    sql_path = OpenStudio::Path.new("#{run_dir}/EnergyPlus/eplusout.sql")

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')

  else # method to running simulation within measure using OpenStudio 2.x WorkflowJSON
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Running with OS 2.x WorkflowJSON.')

    # Copy the weather file to this directory
    epw_name = 'in.epw'
    begin
      FileUtils.copy(epw_path.to_s, "#{run_dir}/#{epw_name}")
    rescue
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Due to limitations on Windows file path lengths, this measure won't work unless your project is located in a directory whose filepath is less than 90 characters long, including slashes.")
      return false
    end

    workflow.setSeedFile(osm_name)
    workflow.setWeatherFile(epw_name)
    workflow.saveAs(File.absolute_path(osw_path.to_s))

    cli_path = OpenStudio.getOpenStudioCLI
    cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
    puts cmd
    system(cmd)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')

    sql_path = OpenStudio::Path.new("#{run_dir}/run/eplusout.sql")

  end

  # TODO: Delete the eplustbl.htm and other files created
  # by the run for cleanliness.

  if OpenStudio.exists(sql_path)
    sql = OpenStudio::SqlFile.new(sql_path)
    # Check to make sure the sql file is readable,
    # which won't be true if EnergyPlus crashed during simulation.
    unless sql.connectionOpen
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed, cannot create model.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
      return false
    end
    # Attach the sql file from the run to the model
    model.setSqlFile(sql)
  else
    OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the run couldn't be found here: #{sql_path}.")
    return false
  end

  # Report severe errors in the run
  error_query = "SELECT ErrorMessage
      FROM Errors
      WHERE ErrorType in(1,2)"
  errs = model.sqlFile.get.execAndReturnVectorOfString(error_query)
  if errs.is_initialized
    errs = errs.get
  end
  # Check that the run completed
  completed_query = 'SELECT Completed FROM Simulations'
  completed = model.sqlFile.get.execAndReturnFirstDouble(completed_query)
  if completed.is_initialized
    completed = completed.get
    if completed.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run did not finish and had following errors: #{errs.join('\n')}")
      return false
    end
  end

  # Check that the run completed with no severe errors
  completed_successfully_query = 'SELECT CompletedSuccessfully FROM Simulations'
  completed_successfully = model.sqlFile.get.execAndReturnFirstDouble(completed_successfully_query)
  if completed_successfully.is_initialized
    completed_successfully = completed_successfully.get
    if completed_successfully.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed with the following severe or fatal errors: #{errs.join('\n')}")
      return false
    end
  end

  # Log any severe errors that did not cause simulation to fail
  unless errs.empty?
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The run completed but had the following severe errors: #{errs.join('\n')}")
  end

  return true
end

# add output variables to the model
def set_output_variables(model)
  model.getOutputVariables.each do |ivar|
    ivar.remove
  end
  out_vars = ['Site Outdoor Air DryBulb Temperature',
  'Site Outdoor Air Humidity Ratio',
  'Site Outdoor Air Barometric Pressure',
  'Zone Ideal Loads Zone Sensible Heating Energy',
  'Zone Ideal Loads Supply Air Sensible Cooling Energy',
  'Zone Ideal Loads Supply Air Latent Cooling Energy'
  ]
  rep_frequency = 'Hourly'
  key_value = '*'
  out_vars.each do |var_name|
    outputVariable = OpenStudio::Model::OutputVariable.new(var_name, model)
    outputVariable.setReportingFrequency(rep_frequency)
    outputVariable.setKeyValue(key_value)
  end
end

code_set = 'NECB2017'
primary_heating_fuel = "Electricity" #"DefaultFuel"  #"NaturalGas"
wfiles = get_loc_list
building_types = ['SmallOffice'] #['SmallOffice' ,'MediumOffice','LargeOffice','QuickServiceRestaurant','FullServiceRestaurant','MidriseApartment',
#'HighriseApartment','SmallHotel','LargeHotel','PrimarySchool','SecondarySchool','RetailStripmall','Warehouse','RetailStandalone']

building_types.each do |btype|
  wfiles.each do |prov,epw_names|
    epw_names.each do |epw_file|
      model,run_dir = create_model_and_regression_test(building_type: btype,epw_file: epw_file,template: code_set, primary_heating_fuel: primary_heating_fuel)
      #set_output_variables(model)
      #model_run_simulation_and_log_errors(model, run_dir) 
    end
  end
end
