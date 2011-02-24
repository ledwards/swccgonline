owner_role = Role.find_or_create_by_name("owner")
admin_role = Role.find_or_create_by_name("admin")
card_admin_role = Role.find_or_create_by_name("card_admin")

admin_user = User.new(:email => "admin@swccgonline.com", :password => "password", :password_confirmation => "password")
admin_user.roles << admin_role
admin_user.save!

files = ["#{Rails.root}/db/lightside.cdf", "#{Rails.root}/db/darkside.cdf"]
files.each do |file|
  CardImporter.new.import_file(file)
end
