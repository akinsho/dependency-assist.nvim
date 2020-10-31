local Package = {}

function Package:new(json)
	local o = vim.fn.json_decode(json)
	setmetatable(o, self)
	self.__index = self
	return o
end

return Package
-- {
-- 	"archive_url" : "https://pub.dartlang.org/packages/artemis/versions/6.15.1-beta.1.tar.gz",
-- 	"published" : "2020-10-13T07:36:06.406990Z",
-- 	"pubspec" : {
-- 		"dependencies" : {
-- 			"build" : "^1.3.0",
-- 			"build_config" : "^0.4.2",
-- 			"code_builder" : "^3.4.1",
-- 			"collection" : "^1.14.13",
-- 			"dart_style" : "^1.3.6",
-- 			"equatable" : "^1.2.5",
-- 			"glob" : "^1.2.0",
-- 			"gql" : "^0.12.3",
-- 			"gql_code_gen" : "^0.1.5",
-- 			"gql_dedupe_link" : "^1.0.10",
-- 			"gql_exec" : "^0.2.5",
-- 			"gql_http_link" : "^0.3.2",
-- 			"gql_link" : "^0.3.1-alpha",
-- 			"http" : "^0.12.2",
-- 			"json_annotation" : "^3.1.0",
-- 			"meta" : "^1.2.3",
-- 			"path" : "^1.7.0",
-- 			"recase" : "^3.0.0",
-- 			"source_gen" : "^0.9.7+1",
-- 			"yaml" : "^2.2.1"
-- 		},
-- 		"description" : "Build dart types from GraphQL schemas and queries (using Introspection Query).",
-- 		"dev_dependencies" : {
-- 			"args" : "^1.6.0",
-- 			"build_resolvers" : "^1.3.11",
-- 			"build_runner" : "^1.10.1",
-- 			"build_test" : "^1.2.2",
-- 			"json_serializable" : "^3.5.0",
-- 			"logging" : "^0.11.4",
-- 			"pedantic" : "^1.9.2",
-- 			"test" : "^1.15.4"
-- 		},
-- 		"environment" : {
-- 			"sdk" : ">=2.8.0 <3.0.0"
-- 		},
-- 		"homepage" : "https://github.com/comigor/artemis",
-- 		"name" : "artemis",
-- 		"version" : "6.15.1-beta.1"
-- 	},
-- 	"version" : "6.15.1-beta.1"
-- }
