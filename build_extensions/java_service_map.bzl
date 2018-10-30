
def java_service_map(
    name, providers, compatible_with=None, restricted_to=None, visibility=None):
  """
  A rule type that generates service provider mappings for use in Java JAR files

  Args:
    name: A unique name. (Name)
    providers: Mapping of services to service providers.
      (Dictionary of strings to string lists)
      A dictionary whose key is the fully-qualified binary name of the service's
      type. (i.e. The interface or abstract class.) The value should be a list
      of strings that are the fully-qualified names of the concrete
      implementations.

  To use, specify a map of services (interfaces, abstract classes, etc.) to
  concrete implementations using a java_service_map rule in your BUILD file.
  The output of this rule can then be added to the 'deps' of other Java
  library or binary targets. For example:

    load("//build_extensions/java_service_map.bzl", "java_service_map")

    java_service_map(
        name = "my_service_map",
        providers = {
            "com.google.myservice.MyInterface": [
                "com.google.myservice.impl.MyClass",
                "com.google.myservice.impl.MyOtherClass",
            ],
            # ...
        },
    )

    java_library(
        name = "my_service_lib",
        srcs = [
            "impl/MyClass.java",
            "impl/MyOtherClass.java",
            # ...
        ],
        deps = [
            ":my_service_map",
            # ...
        ],
    )

  The 'providers' attribute of the build rule is a dictionary that maps service
  names to a list of providers. The key of the dictionary is a string that is
  the fully-qualified binary name of the service's type. (i.e. The interface or
  abstract class.) The value is a list of strings that are the fully-qualified
  names of the concrete implementations. The output of this rule is a JAR file
  that contains the appropriate files in META-INF/services.

  This rule generalizes the strategy outlined by kylemarvin:
  http://wiki/Nonconf/JavaLibraryMetaInf
  """

  # Make sure the directories exist
  files_dir = "$(@D)/" + name + "_files"
  services_dir = files_dir + "/META-INF/services"
  cmd = "rm -rf " + files_dir + ";"
  cmd += "mkdir -p " + services_dir + ";"

  # Write individual META-INF files
  for service, provider_list in sorted(providers.items()):
    file_path = services_dir + "/" + service
    cmd += ("echo '# Generated by Blaze' > " + file_path + ";")
    for provider in provider_list:
      cmd += ("echo '" + provider + "' >> " + file_path + ";")

  # Make a JAR file including all the manifest files.
  # Use the 'zip' command instead of 'jar' to help with bazel's output caching.
  #cmd += zip_cmd + " -q -jt -X -wd " + files_dir + " -r $@ META-INF"
  cmd += "cwd=$$(pwd); "
  cmd += "cd " + files_dir + "; "
  cmd += "zip -X -r $$cwd/$@ .; "
  cmd += "cd $$cwd"

  # Go!
  native.genrule(
      name = name + "_gen",
      srcs = [],
      outs = [name + ".jar"],
      compatible_with = compatible_with,
      restricted_to = restricted_to,
      cmd = cmd,
      visibility = visibility)

  native.java_import(
      name = name,
      jars = [name + ".jar"],
      compatible_with = compatible_with,
      restricted_to = restricted_to,
      visibility = visibility)