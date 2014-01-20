# tests uninstall using msu provider
package { 'KB2506143' :
	ensure => absent,
	provider => msu
}