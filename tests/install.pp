# tests install using msu provider
package { 'KB2506143' :
	ensure => present,
	provider => msu,
	source => 'C:\\Windows6.1-KB2506143-x64.msu',
}