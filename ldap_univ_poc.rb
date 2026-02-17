
require 'net/ldap'
require 'dotenv/load'

username = ENV['LDAP_USERNAME']
password = ENV['LDAP_PASSWORD']

if username.nil? || password.nil?
  puts "Erreur: Les variables d'environnement LDAP_USERNAME et LDAP_PASSWORD doivent etre definies."
  puts "Usage: LDAP_USERNAME='votre_user' LDAP_PASSWORD='votre_mdp' ruby ldap_univ_poc.rb"
  exit 1
end

ldap_config = {
  host: 'montet-dc1.ad.univ-lorraine.fr',
  port: 636,
  encryption: { method: :simple_tls },
  auth: {
    method: :simple,
    username: "#{username}@univ-lorraine.fr",
    password: password
  }
}

puts "Connexion a #{ldap_config[:host]} en tant que #{username}..."

ldap = Net::LDAP.new(ldap_config)

if ldap.bind
  puts "Authentification reussie"
  
  # On élargit la recherche à tous les utilisateurs (Personnels et Etudiants)
  base_dn = 'OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr'
  filter = Net::LDAP::Filter.eq('sAMAccountName', username)
  
  puts "Recherche des details de l'utilisateur dans #{base_dn}..."
  
  ldap.search(base: base_dn, filter: filter) do |entry|
    puts "Utilisateur trouve: #{entry.dn}"
    puts "Nom: #{entry.cn.first}" if entry.cn
    puts "Email: #{entry.mail.first}" if entry.mail
    
    if entry.respond_to?(:memberOf)
      puts "Membre de:"
      entry.memberOf.each do |group|
        puts "  - #{group}"
        if group.include?('GGA_STP_FHB--')
          puts "    -> IUTNC detecte"
        elsif group.include?('GGA_STP_FHBAB')
          puts "    -> Departement Informatique detecte"
        end
      end
    end
    
    puts "-" * 20
  end
  
  if ldap.get_operation_result.code != 0
    puts "Echec de la recherche: #{ldap.get_operation_result.message}"
  end
else
  puts "Echec de l'authentification: #{ldap.get_operation_result.message}"
end
