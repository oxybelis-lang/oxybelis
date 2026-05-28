# typed: true
# frozen_string_literal: true

# Oxybelis – a statically-typed, Python-inspired language that transpiles to C++
#
# Install:
#   brew tap oxybelis/oxybelis
#   brew install oxybelis
#
# Or from this file directly:
#   brew install --formula contrib/homebrew/oxybelis.rb

class Oxybelis < Formula
  desc "Statically-typed language that transpiles to C++"
  homepage "https://github.com/oxybelis/oxybelis"
  license "GPL-3.0-only"
  version "0.1.0"

  # ── Linux x86_64 ──────────────────────────────────────────
  on_linux do
    on_intel do
      url "https://github.com/oxybelis/oxybelis/releases/download/v#{version}/oxybelis-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000" # UPDATE
    end
    on_arm do
      url "https://github.com/oxybelis/oxybelis/releases/download/v#{version}/oxybelis-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000" # UPDATE
    end
  end

  # ── macOS x86_64 ──────────────────────────────────────────
  on_macos do
    on_intel do
      url "https://github.com/oxybelis/oxybelis/releases/download/v#{version}/oxybelis-x86_64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000" # UPDATE
    end
    on_arm do
      url "https://github.com/oxybelis/oxybelis/releases/download/v#{version}/oxybelis-aarch64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000" # UPDATE
    end
  end

  def install
    bin.install "oxybelis"
    bin.install "ox-fmt"
    bin.install "ox-lsp"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/oxybelis --help")
    assert_match "code formatter", shell_output("#{bin}/ox-fmt --help")
    assert_match "Language Server", shell_output("#{bin}/ox-lsp --help")
  end
end
