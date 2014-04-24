# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


Room.create([ { name: "Hubben", allow_party: true, only_group: true }, { name: "Grupprummet", allow_party: false, only_group: false }])

Term.create(title: 'Checklista', content: File.read('checklista.md'))
