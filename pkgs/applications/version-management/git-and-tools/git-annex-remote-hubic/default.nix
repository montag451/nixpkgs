{ stdenv, fetchFromGitHub, python34Packages }:

python34Packages.buildPythonApplication rec {
  name = "git-annex-remote-hubic-${version}";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "montag451";
    repo = "git-annex-remote-hubic";
    rev = "master";
    sha256 = "1rbj6p3rwmrbfi32gppw5z484p5qi7ac83jg5wvhvippw6zv8ja7";
  };

  propagatedBuildInputs = with python34Packages; [
    swiftclient
    dateutil
    rauth
  ];

  #doCheck = false;

  meta = with stdenv.lib; {
    homepage = https://github.com/montag451/git-annex-remote-hubic;
    description = "hubiC remote for git-annex";
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = [ maintainers.montag451 ];
  };
}
