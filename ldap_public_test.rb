
require 'net/ldap'

ldap_config = {
  host: 'ldap.forumsys.com',
  port: 389,
  auth: {
    method: :simple,
    username: 'cn=read-only-admin,dc=example,dc=com',
    password: 'password'
  }
}

puts "Connexion a #{ldap_config[:host]}..."

ldap = Net::LDAP.new(ldap_config)

if ldap.bind
  puts "Authentification reussie"
  
  base_dn = 'dc=example,dc=com'
  filter = Net::LDAP::Filter.eq('objectClass', 'person')
  
  puts "Recherche d'utilisateurs dans #{base_dn}..."
  
  ldap.search(base: base_dn, filter: filter) do |entry|
    puts "DN: #{entry.dn}"
    entry.each do |attribute, values|
      puts "   #{attribute}: #{values.inspect}"
    end
    puts "-" * 20
  end
  
  if ldap.get_operation_result.code != 0
    puts "Echec de la recherche: #{ldap.get_operation_result.message}"
  end
else
  puts "Echec de l'authentification: #{ldap.get_operation_result.message}"
end
