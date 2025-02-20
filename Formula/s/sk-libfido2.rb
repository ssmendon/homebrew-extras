class SkLibfido2 < Formula
  desc "FIDO2 provider for SSH"
  homepage "https://www.openssh.com/"
  license "SSH-OpenSSH"

  # TODO: head-only for now; this option isn't stable yet
  head do
    url "https://github.com/openssh/openssh-portable.git", branch: "master"

    # <https://github.com/openssh/openssh-portable/tree/V_9_9?tab=readme-ov-file#building-from-git>
    depends_on "autoconf" => :build
    depends_on "automake" => :build
  end

  keg_only "it isn't intended to be linked against"

  depends_on "pkgconf" => :build
  depends_on "libfido2"
  depends_on "openssl@3"

  def shlibext
    OS.mac? ? ".dylib" : ".so"
  end

  def install
    args = %W[
      --sysconfdir=#{etc}/ssh
      --with-ssl-dir=#{Formula["openssl@3"].opt_prefix}
      --with-security-key-standalone
      --without-zlib
    ]

    args << "--with-privsep-path=#{var}/lib/sshd" if OS.linux?

    system "autoreconf"
    system "./configure", *args, *std_configure_args

    # sk-libfido2.dylib doesn't need any extra libs to function
    system "make", "TARGETS=sk-libfido2#{shlibext}", "LIBS=", "sk-libfido2#{shlibext}"
    ENV.deparallelize

    # don't install OpenSSH, just install the helper lib and its private include
    include.install "sk-api.h"
    lib.install "sk-libfido2#{shlibext}"
  end

  def caveats
    <<~EOS
      Review the manual(s) for ssh and its subprograms for tips on how to use this provider.

      The provider library should be installed in:
        #{lib}
    EOS
  end

  test do
    # link to the library and check its version against the header
    (testpath/"test.c").write <<~C
      /* <stdint.h> must be included before
         since this isn't designed as a real library */
      #include <stdint.h>
      #include <sk-api.h>

      int main(void) {
        uint32_t vers = sk_api_version();
        if (vers == SSH_SK_VERSION_MAJOR)
          return 0;
        else
          return 1;
      }
    C

    # compile pedantically, so any missing references abort the build
    # and fail the test
    args = %W[
      -pedantic-errors
      -I#{include}
      -o test
      --
      test.c
      #{lib}/sk-libfido2#{shlibext}
    ]

    system ENV.cc, *args
    system "./test"
  end
end
