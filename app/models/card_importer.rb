# coding: utf-8

class CardImporter
  attr_accessor :card
  
  def initialize
    @card = Card.new
    @server = "http://stuff.ledwards.com/starwars"
    @card_string = nil
    @characteristics = []
  end
  
  def import_file(filename)
    file = File.open(filename,"r")

    while (line = file.gets)
     begin
        @card = import(line)
        @card.save! unless @card.nil?
     rescue
       Rails.logger.error "CardImporter::Error on line -- #{line}"
     end
    end

    file.close
  end
  
  def import(card_string)
    @card = Card.new
    @card_string = card_string
    @characteristics = []
    
    card_re = /card\s"(.*?)"\s"([<>@•]*)(.*)\(([^V]*)\)\\n(\S*)\s(.*?)\[(.*)\]\s?\\nSet:\s(.*?)\\n/
    if card_match = card_re.match(@card_string)
      self.populate_card_fields(card_match)
      unless self.should_reject
        self.correct_bad_import_data
        self.import_local_card_images
        self.set_attributes
        self.set_characteristics
      end
    else
      return nil
    end
    return self.should_reject ? nil : @card
  end
  
  protected
  
  def should_reject
    vdfs = ["Your Insight Serves You Well (Death Star II) (V)",
      "Ounee Ta (Premium) (V)",
      "Another Pathetic Lifeform (Coruscant) (V)",
      "Do They Have A Code Clearance? (Coruscant) (V)",
      "Leave Them To Me (Death Star II) (V)",
      "No Escape (Premium) (V)",
      "Wipe Them Out, All Of Them (Coruscant) (V)",
      "You Cannot Hide Forever (Death Star II) (V)",
      "Alter (Coruscant) (V)",
      "Planetary Defenses (V)",
      "Let's Keep A Little Optimism Here (Death Star II) (V)",
      "Hyperoute Navigation Chart"]
    
    return true if (@card.title =~ /\(AI\)/ || vdfs.include?(@card.title))
  end
  
  def populate_card_fields(card_match)
    image_url = card_match.captures[0]
    @card.uniqueness = card_match.captures[1]
    @card.title = card_match.captures[2].strip.gsub("@","").gsub("•","")
    @card.card_attributes << CardAttribute.new(:name => "Destiny", :value => card_match.captures[3])
    @card.side = card_match.captures[4].strip
    @card.card_type = card_match.captures[5].strip
    @card.rarity = card_match.captures[6].strip
    @card.expansion = card_match.captures[7].strip
    
    @card.card_type, @card.subtype = @card.card_type.split(" - ")
    if ["Effect", "Interrupt", "Weapon", "Vehicle"].include?(@card.card_type)
      @card.subtype = "#{@card.subtype} #{@card.card_type}"
    end

    if @card.uniqueness.present?
      @card.uniqueness.gsub!('@','•')
      @card.uniqueness.gsub!('<>','◊')
      if @card.title =~ /&/
        @card.title = @card.title.gsub('@','').gsub("•","")
        @card.uniqueness = "•" if @card.uniqueness == "••"
      end
    else
      @card.uniqueness = ""
    end
    
    lore_re = /Lore: (.*)(\\n)+Text/
    @card.lore = lore_re.match(@card_string).captures[0].sub('\n','') if not lore_re.match(@card_string).nil?
    
    if @card.card_type == "Objective"
      obj_gametext_re = /\\n\\n(.*)"/
      @card.gametext = obj_gametext_re.match(@card_string).captures[0].gsub('\n',"\n").strip
    else
      gametext_re = /Text:(.*)"/
      @card.gametext = gametext_re.match(@card_string).captures[0].sub('\n','\n').gsub('ï','•').gsub("<>","◊").strip if not gametext_re.match(@card_string).nil?
    end
  end
  
  def correct_bad_import_data
    @card.title = "Jabba's Prize" if @card.title == "Jabba's Prize/Jabba's Prize"
    @card.title = "Obi-Wan Kenobi, Padawan Learner" if @card.title == "Obi-wan Kenobi, Padawan Learner"
    @card.title = "Obi-Wan Kenobi, Padawan Learner (V)" if @card.title == "Obi-wan Kenobi, Padawan Learner (V)"
    @card.title = "Alter (V)" if @card.title == "Alter (Premiere) (V)"
    @card.expansion.gsub!("2 Player", "Two Player")
    @card.expansion = "Virtual Defensive Shields" if @card.expansion == "Virtual Defensive Shield"
  end
  
  def set_attributes
    attribute_names = ["Ferocity", "Power", "Ability", "Politics", "Armor", "Maneuever", "Hyperspeed", "Landspeed", "Deploy", "Forfeit"]
    attributes = []
    attribute_names.each do |a| 
      attribute = find_attribute(a)
      @card.card_attributes << attribute if attribute
      @ability = attribute.value if attribute && a == "Ability"
    end
  end
  
  def set_characteristics
    #TODO: Lore-based characteristics
    
    icons_re = /Icons: (.+?)\\n/
    if icons_re.match(@card_string) && icons = icons_re.match(@card_string).captures[0]
      icons.sub!('Pilot','Permanent Pilot') if @card.card_type == 'Starship' or card.card_type == 'Vehicle'
      icons.sub!('Space','') if @card.card_type == "Location"       # ...what is this for?      
      icons.each_line(separator=',') do |icon|
        @characteristics << formatted_characteristic(icon)
      end
    end
        
    @characteristics << 'Force Attuned' if @ability == '3'
    @characteristics << 'Force Sensitive' if @ability == '4' || @ability == '5'        
    @characteristics << 'Dark Jedi' if @ability == '6' && @card.side == 'Dark'
    @characteristics << 'Jedi Knight' if @ability == '6' && @card.side == 'Light'
    @characteristics << 'Dark Jedi Master' if @ability == '7' && @card.side == 'Dark'
    @characteristics << 'Jedi Master' if @ability == '7' && @card.side == 'Light'
    
    @characteristics.each do |c|
      @card.card_characteristics << CardCharacteristic.find_or_create_by_name(c) unless c.nil?
    end            
  end
  
  def formatted_characteristic(characteristic)
    corrections = {
      "Mobil" => "Mobile",
      "Starship" => "Starship Site",
      "Anakin Permanent Pilot" => "Permanent Pilot",
      "Episode 1" => "Episode I"
    }
    return corrections[characteristic] || characteristic.delete(',').strip
  end
  
  def import_remote_card_images
    @card.card_image = open(URI.parse(self.card_image_url))
    @card.card_back_image = open(URI.parse(self.card_back_image_url)) if @card.is_flippable?
    @card.vslip_image = open(URI.parse(self.vslip_image_url)) if @card.is_virtual?
    @card.vslip_back_image = open(URI.parse(self.vslip_back_image_url)) if @card.is_virtual? && @card.is_flippable?
  end
  
  def import_local_card_images
    @card.card_image = File.open(self.card_image_path)
    @card.card_back_image = File.open(self.card_back_image_path) if @card.is_flippable?
    @card.vslip_image = File.open(self.vslip_image_path) if @card.is_virtual?
    @card.vslip_back_image = File.open(self.vslip_back_image_path) if @card.is_virtual? && @card.is_flippable?
  end
  
  def card_image_path
    return nil if @card.invalid?
    "#{Rails.configuration.card_image_import_path}/#{self.subdir_for_local_card_image}/#{self.filename_for_card_image}.gif"
  end
  
  def card_back_image_path
    return nil unless @card.card_type == "Objective"    
    "#{Rails.configuration.card_image_import_path}/#{self.subdir_for_local_card_image}/#{self.filename_for_card_back_image}.gif"
  end
  
  def vslip_image_path
    return nil unless @card.is_virtual?
    "#{Rails.configuration.vslip_image_import_path}/#{@card.side.downcase}/#{self.filename_for_vslip_image}.png"
  end
  
  def vslip_back_image_path
    return nil unless @card.is_virtual? && @card.card_type == "Objective"
    "#{Rails.configuration.vslip_image_import_path}/#{@card.side.downcase}/#{self.filename_for_vslip_back_image}.png"
  end
  
  def card_image_url
    return nil if @card.invalid?
    "#{@server}/cards/#{self.subdir_for_remote_card_image}/#{self.filename_for_card_image}.gif"
  end
  
  def card_back_image_url
    return nil unless @card.card_type == "Objective"    
    "#{@server}/cards/#{self.subdir_for_remote_card_image}/#{self.filename_for_card_back_image}.gif"
  end
  
  def vslip_image_url
    return nil unless @card.is_virtual?
    "#{@server}/vslips/#{@card.side.downcase}/#{self.filename_for_vslip_image}.png"
  end
  
  def vslip_back_image_url
    return nil unless @card.is_virtual? && @card.card_type == "Objective"
    "#{@server}/vslips/#{@card.side.downcase}/#{self.filename_for_vslip_back_image}.png"
  end
  
  def find_attribute(attr_name)
    attr_re = /#{attr_name}: (.+?)/
    if attr_re.match(@card_string)
      value = attr_re.match(@card_string).captures[0]
      return CardAttribute.new(:name => attr_name, :value => value)
    else
      return nil
    end
  end
    
  def filename_for_droid
    exceptions = ["Premiere", "A New Hope", "Special Edition", "Virtual Block 1"]
    exceptions.include?(@card.expansion) ? @card.title.gsub(/\(.+\)/,"") : @card.title
  end
  
  def transform_filename(filename)
    filename.gsub("(V)","").gsub("(v)","").downcase.gsub(/[^0-9a-z%]/i, "")
  end
  
  def subdir_for_remote_card_image
    "#{@card.expansion.gsub("'","").gsub(" ","").gsub("Block","")}-#{@card.side}/large"
  end
  
  def subdir_for_local_card_image
    "#{@card.expansion.gsub("'","").gsub(" ","").gsub("Block","")}-#{@card.side}"
  end
  
  def subdir_for_vslip_image
    @card.side.downcase
  end
  
  def filename_for_card_image
    filename_re = /t_(.*)" "/
    filename_re.match(@card_string).captures[0].split("/").first
  end
  
  def filename_for_card_back_image
    filename_re = /t_(.*)" /
    filename_re.match(@card_string).captures[0].split("/").last
  end
  
  def filename_for_vslip_image
    exceptions = {
        "Virtual Block 1" => {
          "Boba Fett (V)" => "bobafettse"
        },
        "Virtual Block 2" => {
          "Boba Fett (V)" => "bobafettcc",
          "Fear (V)" => "fear"
        },
        "Virtual Block 6" => {
          "Jabba's Prize" => "jabbasprize"
        },
        "Virtual Block 7" => {
          "Alter (V)" => "alter"
        }
      }
    filename_re = /t_(.*)" /
    exceptions[@card.expansion] && exceptions[@card.expansion][@card.title] ? exceptions[@card.expansion][@card.title] : filename_re.match(@card_string).captures.first.split("/").first.gsub("&","")
  end
  
  def filename_for_vslip_back_image
    filename_re = /t_(.*)" /
    filename_re.match(@card_string).captures[0].split("/").last
  end
end