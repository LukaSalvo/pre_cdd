#!/usr/bin/env ruby
# Script de test LDAP avec le serveur public ldap.forumsys.com
# Étape 1 du projet : Découverte de LDAP et raccordement à un serveur de test

require 'net/ldap'

LDAP_HOST = 'ldap.forumsys.com'
LDAP_PORT = 389
BASE_DN   = 'dc=example,dc=com'

# --- Fonction utilitaire ---

def separator
  puts '-' * 50
end

# --- 1. Connexion admin en lecture seule ---

puts '=' * 50
puts '  TEST 1 : Bind en tant que read-only-admin'
puts '=' * 50

admin_ldap = Net::LDAP.new(
  host: LDAP_HOST,
  port: LDAP_PORT,
  auth: {
    method: :simple,
    username: "cn=read-only-admin,#{BASE_DN}",
    password: 'password'
  }
)

if admin_ldap.bind
  puts "✓ Authentification admin reussie"
else
  puts "✗ Echec de l'authentification admin: #{admin_ldap.get_operation_result.message}"
  exit 1
end

# --- 2. Exploration de la structure de l'annuaire (DIT) ---

puts
puts '=' * 50
puts '  TEST 2 : Exploration de la structure (DIT)'
puts '=' * 50

puts "\nRecherche de toutes les entrees sous #{BASE_DN}...\n"

# Recherche de toutes les unités organisationnelles
filter_ou = Net::LDAP::Filter.eq('objectClass', 'organizationalUnit')
admin_ldap.search(base: BASE_DN, filter: filter_ou) do |entry|
  puts "  OU trouvee: #{entry.dn}"
end

# Recherche de tous les groupes
filter_group = Net::LDAP::Filter.eq('objectClass', 'groupOfUniqueNames')
admin_ldap.search(base: BASE_DN, filter: filter_group) do |entry|
  puts "  Groupe trouve: #{entry.dn}"
  if entry.respond_to?(:uniqueMember)
    entry.uniqueMember.each do |member|
      puts "    └ Membre: #{member}"
    end
  end
end

# --- 3. Liste de tous les utilisateurs ---

puts
puts '=' * 50
puts '  TEST 3 : Liste des utilisateurs'
puts '=' * 50

filter_person = Net::LDAP::Filter.eq('objectClass', 'person')
users = []

admin_ldap.search(base: BASE_DN, filter: filter_person) do |entry|
  users << entry
  puts "\n  DN: #{entry.dn}"
  entry.each do |attribute, values|
    puts "    #{attribute}: #{values.join(', ')}"
  end
  separator
end

puts "\nNombre total d'utilisateurs: #{users.length}"

# --- 4. Bind avec des utilisateurs specifiques ---

puts
puts '=' * 50
puts '  TEST 4 : Authentification avec des utilisateurs individuels'
puts '=' * 50

test_users = [
  { uid: 'einstein', description: 'Albert Einstein' },
  { uid: 'tesla',    description: 'Nikola Tesla' },
  { uid: 'newton',   description: 'Isaac Newton' },
  { uid: 'galileo', description: 'Galileo Galilei' },
  { uid: 'euler',    description: 'Leonhard Euler' }
]

test_users.each do |user|
  user_dn = "uid=#{user[:uid]},#{BASE_DN}"
  user_ldap = Net::LDAP.new(
    host: LDAP_HOST,
    port: LDAP_PORT,
    auth: {
      method: :simple,
      username: user_dn,
      password: 'password'
    }
  )

  if user_ldap.bind
    puts "  ✓ #{user[:description]} (#{user_dn}) : authentification reussie"

    # Recherche des infos de cet utilisateur
    filter = Net::LDAP::Filter.eq('uid', user[:uid])
    user_ldap.search(base: BASE_DN, filter: filter) do |entry|
      puts "    Mail: #{entry.mail.first}" if entry.respond_to?(:mail) && entry.mail
      puts "    Tel: #{entry.telephoneNumber.first}" if entry.respond_to?(:telephoneNumber) && entry.telephoneNumber
    end
  else
    puts "  ✗ #{user[:description]} (#{user_dn}) : echec - #{user_ldap.get_operation_result.message}"
  end
end

# --- 5. Test des filtres de recherche ---

puts
puts '=' * 50
puts '  TEST 5 : Exemples de filtres de recherche'
puts '=' * 50

# Filtre par mail
puts "\n  Recherche par mail contenant 'einstein':"
filter_mail = Net::LDAP::Filter.contains('mail', 'einstein')
admin_ldap.search(base: BASE_DN, filter: filter_mail) do |entry|
  puts "    Trouve: #{entry.dn} -> #{entry.mail.first}" if entry.respond_to?(:mail)
end

# Filtre combiné (AND)
puts "\n  Recherche combinee (objectClass=person AND uid=tesla):"
filter_combined = Net::LDAP::Filter.eq('objectClass', 'person') & Net::LDAP::Filter.eq('uid', 'tesla')
admin_ldap.search(base: BASE_DN, filter: filter_combined) do |entry|
  puts "    Trouve: #{entry.dn}"
end

# Filtre OR
puts "\n  Recherche OR (uid=einstein OU uid=newton):"
filter_or = Net::LDAP::Filter.eq('uid', 'einstein') | Net::LDAP::Filter.eq('uid', 'newton')
admin_ldap.search(base: BASE_DN, filter: filter_or) do |entry|
  puts "    Trouve: #{entry.dn}"
end

puts
puts '=' * 50
puts '  Tous les tests termines avec succes !'
puts '=' * 50
