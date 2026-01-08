#!/usr/bin/env python3
"""
UUID Blob Mapper - Maps BOSH blob UUIDs to filenames by analyzing git history

This tool analyzes the complete git history of config/blobs.yml files across
all buildpack release repositories to create a comprehensive mapping of UUID
blob IDs to human-readable filenames.
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import signal
import http.server
import socketserver
import threading
import webbrowser
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Set
import yaml

# ANSI Colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

@dataclass
class BlobEntry:
    """Represents a single blob entry from config/blobs.yml"""
    uuid: str
    filename: str
    size: int
    sha: str
    repo: str
    commit: str
    date: str
    author: str
    tags: str = ""  # Comma-separated list of tags/releases
    
    def to_csv_row(self) -> List[str]:
        return [
            self.uuid, self.filename, str(self.size), self.sha,
            self.repo, self.commit, self.date, self.author, self.tags
        ]

@dataclass
class S3BlobInfo:
    """Represents a UUID file in S3"""
    uuid: str
    size: int
    last_modified: str

class UUIDMapper:
    """Main class for UUID blob mapping"""
    
    REPOS = [
        # Buildpack BOSH releases
        "https://github.com/cloudfoundry/binary-buildpack-release",
        "https://github.com/cloudfoundry/dotnet-core-buildpack-release",
        "https://github.com/cloudfoundry/go-buildpack-release",
        "https://github.com/cloudfoundry/java-buildpack-release",
        "https://github.com/cloudfoundry/java-offline-buildpack-release",
        "https://github.com/cloudfoundry/nodejs-buildpack-release",
        "https://github.com/cloudfoundry/php-buildpack-release",
        "https://github.com/cloudfoundry/python-buildpack-release",
        "https://github.com/cloudfoundry/ruby-buildpack-release",
        "https://github.com/cloudfoundry/staticfile-buildpack-release",
        "https://github.com/cloudfoundry/hwc-buildpack-release",
        "https://github.com/cloudfoundry/nginx-buildpack-release",
        "https://github.com/cloudfoundry/r-buildpack-release",

        # Additional repos can be added here
        "https://github.com/cloudfoundry/cflinuxfs3-release",
        "https://github.com/cloudfoundry/cflinuxfs4-release",
    ]
    
    def __init__(self, work_dir: str, output_dir: str, bucket: str, parallel: int = 4, refresh_s3: bool = False):
        self.work_dir = Path(work_dir)
        self.output_dir = Path(output_dir)
        self.bucket = bucket
        self.parallel = parallel
        self.refresh_s3 = refresh_s3
        
        self.work_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.repos_dir = self.work_dir / "repos"
        self.repos_dir.mkdir(exist_ok=True)
        
        self.all_blob_entries: List[BlobEntry] = []
        self.s3_blobs: Dict[str, S3BlobInfo] = {}
        
    def log(self, level: str, message: str):
        """Log a message with color"""
        colors = {
            'INFO': Colors.BLUE,
            'SUCCESS': Colors.GREEN,
            'WARNING': Colors.YELLOW,
            'ERROR': Colors.RED
        }
        color = colors.get(level, Colors.NC)
        print(f"{color}[{level}]{Colors.NC} {message}")
    
    def run_command(self, cmd: List[str], cwd: Optional[Path] = None, capture=True) -> Optional[str]:
        """Run a shell command"""
        try:
            if capture:
                result = subprocess.run(
                    cmd, cwd=cwd, capture_output=True, text=True, check=True
                )
                return result.stdout.strip()
            else:
                subprocess.run(cmd, cwd=cwd, check=True)
                return None
        except subprocess.CalledProcessError as e:
            self.log('ERROR', f"Command failed: {' '.join(cmd)}")
            if capture and e.stderr:
                self.log('ERROR', e.stderr)
            return None
    
    def clone_repo(self, repo_url: str) -> Optional[Path]:
        """Clone or update a repository"""
        repo_name = repo_url.rstrip('/').split('/')[-1].replace('.git', '')
        repo_path = self.repos_dir / repo_name
        
        if repo_path.exists():
            self.log('INFO', f"Updating {repo_name}...")
            self.run_command(['git', 'fetch', '--all', '--quiet'], cwd=repo_path)
        else:
            self.log('INFO', f"Cloning {repo_name}...")
            result = self.run_command(['git', 'clone', '--quiet', repo_url, str(repo_path)])
            if result is None and not repo_path.exists():
                self.log('WARNING', f"Failed to clone {repo_name}")
                return None
        
        return repo_path
    
    def extract_blobs_from_commit(self, repo_path: Path, commit_sha: str) -> List[BlobEntry]:
        """Extract blob entries from a specific commit"""
        repo_name = repo_path.name
        
        blobs_content = self.run_command(
            ['git', 'show', f'{commit_sha}:config/blobs.yml'],
            cwd=repo_path
        )
        
        if not blobs_content:
            return []
        
        commit_date = self.run_command(
            ['git', 'show', '-s', '--format=%ci', commit_sha],
            cwd=repo_path
        )
        commit_author = self.run_command(
            ['git', 'show', '-s', '--format=%an', commit_sha],
            cwd=repo_path
        )
        
        tags_output = self.run_command(
            ['git', 'tag', '--contains', commit_sha],
            cwd=repo_path
        )
        tags = ','.join(tags_output.split('\n')[:5]) if tags_output else ""
        
        try:
            blobs_data = yaml.safe_load(blobs_content)
            if not isinstance(blobs_data, dict):
                return []
        except yaml.YAMLError:
            return []
        
        entries = []
        for filename, blob_info in blobs_data.items():
            if not isinstance(blob_info, dict):
                continue
            
            uuid = blob_info.get('object_id') or blob_info.get('blobstore_id')
            if not uuid:
                continue
            
            entry = BlobEntry(
                uuid=str(uuid),
                filename=filename,
                size=blob_info.get('size', 0),
                sha=blob_info.get('sha') or blob_info.get('sha256', ''),
                repo=repo_name,
                commit=commit_sha,
                date=commit_date or '',
                author=commit_author or '',
                tags=tags
            )
            entries.append(entry)
        
        return entries
    
    def analyze_final_builds(self, repo_path: Path) -> List[BlobEntry]:
        """Analyze .final_builds for compiled package and job blob references"""
        repo_name = repo_path.name
        final_builds_base = repo_path / ".final_builds"
        
        if not final_builds_base.exists():
            return []
        
        self.log('INFO', f"Scanning .final_builds for {repo_name}...")
        
        entries = []
        
        for category in ['packages', 'jobs', 'license']:
            category_dir = final_builds_base / category
            if not category_dir.exists():
                continue
            
            # Check if index.yml exists directly in category (e.g., license/index.yml)
            direct_index = category_dir / "index.yml"
            if direct_index.exists() and direct_index.is_file():
                try:
                    with open(direct_index, 'r') as f:
                        index_data = yaml.safe_load(f)
                    
                    if isinstance(index_data, dict) and 'builds' in index_data:
                        builds = index_data['builds']
                        if isinstance(builds, dict):
                            for build_version, build_info in builds.items():
                                if not isinstance(build_info, dict):
                                    continue
                                
                                blobstore_id = build_info.get('blobstore_id')
                                if not blobstore_id:
                                    continue
                                
                                entry = BlobEntry(
                                    uuid=str(blobstore_id),
                                    filename=f"{category}/{build_version[:12]}",
                                    size=0,
                                    sha=build_info.get('sha1', ''),
                                    repo=repo_name,
                                    commit='final-build',
                                    date='',
                                    author='',
                                    tags=''
                                )
                                entries.append(entry)
                except Exception as e:
                    self.log('WARNING', f"Failed to parse {direct_index}: {e}")
            
            # Process subdirectories (e.g., packages/cflinuxfs4/index.yml)
            for item_dir in category_dir.iterdir():
                if not item_dir.is_dir():
                    continue
                
                index_file = item_dir / "index.yml"
                if not index_file.exists():
                    continue
                
                try:
                    with open(index_file, 'r') as f:
                        index_data = yaml.safe_load(f)
                    
                    if not isinstance(index_data, dict) or 'builds' not in index_data:
                        continue
                    
                    builds = index_data['builds']
                    if not isinstance(builds, dict):
                        continue
                    
                    for build_version, build_info in builds.items():
                        if not isinstance(build_info, dict):
                            continue
                        
                        blobstore_id = build_info.get('blobstore_id')
                        if not blobstore_id:
                            continue
                        
                        entry = BlobEntry(
                            uuid=str(blobstore_id),
                            filename=f"{category}/{item_dir.name}/{build_version[:12]}",
                            size=0,
                            sha=build_info.get('sha1', ''),
                            repo=repo_name,
                            commit='final-build',
                            date='',
                            author='',
                            tags=''
                        )
                        entries.append(entry)
                except Exception as e:
                    self.log('WARNING', f"Failed to parse {index_file}: {e}")
                    continue
        
        if entries:
            self.log('SUCCESS', f"Found {len(entries)} final build blobs in {repo_name}")
        
        return entries
    
    def analyze_repo_history(self, repo_path: Path) -> List[BlobEntry]:
        """Analyze the complete git history of config/blobs.yml"""
        repo_name = repo_path.name
        self.log('INFO', f"Analyzing history for {repo_name}...")
        
        blobs_file = repo_path / "config" / "blobs.yml"
        if not blobs_file.exists():
            self.log('WARNING', f"{repo_name} has no config/blobs.yml")
            return []
        
        # Get all commits that touched config/blobs.yml
        commits_output = self.run_command(
            ['git', 'log', '--all', '--format=%H', '--', 'config/blobs.yml'],
            cwd=repo_path
        )
        
        if not commits_output:
            self.log('WARNING', f"No history found for {repo_name}/config/blobs.yml")
            return []
        
        commits = commits_output.split('\n')
        self.log('INFO', f"Processing {len(commits)} commits for {repo_name}...")
        
        all_entries = []
        for commit in commits:
            entries = self.extract_blobs_from_commit(repo_path, commit)
            all_entries.extend(entries)
        
        self.log('SUCCESS', f"Found {len(all_entries)} blob entries in {repo_name} history")
        return all_entries
    
    def process_all_repos(self):
        """Clone and analyze all repositories"""
        self.log('INFO', f"Processing {len(self.REPOS)} repositories with {self.parallel} parallel workers...")
        
        with ThreadPoolExecutor(max_workers=self.parallel) as executor:
            # Clone repos
            clone_futures = {executor.submit(self.clone_repo, repo): repo for repo in self.REPOS}
            repo_paths = []
            
            for future in as_completed(clone_futures):
                repo_path = future.result()
                if repo_path:
                    repo_paths.append(repo_path)
            
            # Analyze repos (both config/blobs.yml and .final_builds)
            history_futures = {executor.submit(self.analyze_repo_history, path): path for path in repo_paths}
            final_builds_futures = {executor.submit(self.analyze_final_builds, path): path for path in repo_paths}
            
            for future in as_completed(history_futures):
                entries = future.result()
                self.all_blob_entries.extend(entries)
            
            for future in as_completed(final_builds_futures):
                entries = future.result()
                self.all_blob_entries.extend(entries)
        
        self.log('SUCCESS', f"Total blob entries collected: {len(self.all_blob_entries)}")
    
    def save_all_history(self):
        """Save complete blob history to CSV"""
        output_file = self.output_dir / "all_blob_history.csv"
        
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['uuid', 'filename', 'size', 'sha', 'repo', 'commit', 'date', 'author', 'tags'])
            for entry in self.all_blob_entries:
                writer.writerow(entry.to_csv_row())
        
        self.log('SUCCESS', f"Saved complete history to {output_file}")
    
    def create_current_mapping(self):
        """Create current UUID mapping (latest entry per UUID)"""
        sorted_entries = sorted(
            self.all_blob_entries,
            key=lambda e: (e.uuid, e.date),
            reverse=True
        )
        
        seen_uuids = set()
        current_entries = []
        
        for entry in sorted_entries:
            if entry.uuid not in seen_uuids:
                seen_uuids.add(entry.uuid)
                current_entries.append(entry)
        
        output_file = self.output_dir / "uuid_mapping_current.csv"
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['uuid', 'filename', 'size', 'sha', 'repo', 'commit', 'date', 'author', 'tags'])
            for entry in current_entries:
                writer.writerow(entry.to_csv_row())
        
        self.log('SUCCESS', f"Current mapping contains {len(current_entries)} unique UUIDs")
    
    def fetch_s3_contents(self, use_cache=True):
        """Fetch UUID files from S3 bucket"""
        cache_file = self.work_dir / "s3_cache.csv"
        
        if use_cache and cache_file.exists():
            cache_age = (datetime.now() - datetime.fromtimestamp(cache_file.stat().st_mtime)).total_seconds()
            if cache_age < 86400:
                self.log('INFO', f"Using cached S3 contents (age: {cache_age/3600:.1f}h)")
                import re
                uuid_pattern = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
                
                with open(cache_file, 'r') as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        uuid = row['uuid']
                        if uuid_pattern.match(uuid):
                            self.s3_blobs[uuid] = S3BlobInfo(
                                uuid=uuid,
                                size=int(row['size']),
                                last_modified=row['last_modified']
                            )
                
                self.log('SUCCESS', f"Loaded {len(self.s3_blobs)} UUID files from cache")
                
                output_file = self.output_dir / "s3_uuid_files.csv"
                with open(output_file, 'w', newline='') as f:
                    writer = csv.writer(f)
                    writer.writerow(['uuid', 'size', 'last_modified'])
                    for blob in self.s3_blobs.values():
                        writer.writerow([blob.uuid, blob.size, blob.last_modified])
                return
        
        self.log('INFO', f"Fetching S3 bucket contents from s3://{self.bucket}/...")
        
        output = self.run_command(['aws', 's3', 'ls', f's3://{self.bucket}/', '--recursive'])
        if not output:
            self.log('ERROR', "Failed to fetch S3 contents")
            return
        
        import re
        uuid_pattern = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
        
        for line in output.split('\n'):
            parts = line.split()
            if len(parts) >= 4:
                date, time, size, key = parts[0], parts[1], parts[2], parts[3]
                if uuid_pattern.match(key):
                    self.s3_blobs[key] = S3BlobInfo(
                        uuid=key,
                        size=int(size),
                        last_modified=f"{date} {time}"
                    )
        
        with open(cache_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['uuid', 'size', 'last_modified'])
            for blob in self.s3_blobs.values():
                writer.writerow([blob.uuid, blob.size, blob.last_modified])
        
        output_file = self.output_dir / "s3_uuid_files.csv"
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['uuid', 'size', 'last_modified'])
            for blob in self.s3_blobs.values():
                writer.writerow([blob.uuid, blob.size, blob.last_modified])
        
        self.log('SUCCESS', f"Found {len(self.s3_blobs)} UUID files in S3 (cached for 24h)")
    
    def create_release_mapping(self):
        """Create mapping of blobs by release/tag"""
        release_mapping = defaultdict(list)
        
        for entry in self.all_blob_entries:
            if entry.tags:
                for tag in entry.tags.split(','):
                    tag = tag.strip()
                    if tag:
                        release_mapping[f"{entry.repo}/{tag}"].append(entry)
        
        output_file = self.output_dir / "blobs_by_release.csv"
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['release', 'uuid', 'filename', 'size', 'sha', 'commit', 'date'])
            
            for release in sorted(release_mapping.keys()):
                for entry in release_mapping[release]:
                    writer.writerow([
                        release, entry.uuid, entry.filename, entry.size,
                        entry.sha, entry.commit, entry.date
                    ])
        
        self.log('SUCCESS', f"Release mapping contains {len(release_mapping)} releases")
        return release_mapping
    
    def identify_orphaned_blobs(self):
        """Identify blobs in S3 that aren't in any current blobs.yml"""
        # Get current UUIDs
        current_file = self.output_dir / "uuid_mapping_current.csv"
        current_uuids = set()
        
        with open(current_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                current_uuids.add(row['uuid'])
        
        # Find orphaned UUIDs
        orphaned = []
        for uuid, blob_info in self.s3_blobs.items():
            if uuid not in current_uuids:
                orphaned.append(blob_info)
        
        # Save orphaned blobs
        output_file = self.output_dir / "orphaned_blobs.csv"
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['uuid', 'size', 'last_modified', 'status'])
            for blob in sorted(orphaned, key=lambda b: b.size, reverse=True):
                writer.writerow([blob.uuid, blob.size, blob.last_modified, 'orphaned'])
        
        total_size = sum(blob.size for blob in orphaned)
        size_gb = total_size / (1024 ** 3)
        
        self.log('WARNING', f"Orphaned blobs: {len(orphaned)} ({size_gb:.2f} GB)")
        return orphaned
    
    def generate_summary(self, orphaned_blobs: List[S3BlobInfo]):
        """Generate JSON summary"""
        unique_uuids = len(set(entry.uuid for entry in self.all_blob_entries))
        
        current_file = self.output_dir / "uuid_mapping_current.csv"
        with open(current_file, 'r') as f:
            current_count = sum(1 for _ in csv.DictReader(f))
        
        orphaned_size = sum(blob.size for blob in orphaned_blobs)
        
        summary = {
            'generated_at': datetime.utcnow().isoformat() + 'Z',
            'bucket': self.bucket,
            'summary': {
                'total_blob_history_entries': len(self.all_blob_entries),
                'unique_uuids_in_history': unique_uuids,
                'current_active_uuids': current_count,
                'uuids_in_s3': len(self.s3_blobs),
                'orphaned_uuids': len(orphaned_blobs),
                'orphaned_size_bytes': orphaned_size,
                'orphaned_size_gb': orphaned_size / (1024 ** 3),
                'repositories_analyzed': len(set(e.repo for e in self.all_blob_entries))
            }
        }
        
        output_file = self.output_dir / "summary.json"
        with open(output_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        self.log('SUCCESS', f"Summary saved to {output_file}")
        return summary
    
    def generate_html_report(self):
        """Generate interactive HTML report focused on UUID to Release mapping"""
        html_template = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BOSH Blob UUID → Release Mapping</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      max-width: 1600px;
      margin: 0 auto;
      padding: 20px;
      background: #f5f5f5;
    }
    h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; margin-bottom: 5px; }
    .subtitle { color: #666; font-size: 18px; margin-bottom: 20px; }
    h2 { color: #555; margin-top: 30px; border-bottom: 2px solid #ddd; padding-bottom: 8px; }
    
    .search-box {
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      margin: 20px 0;
    }
    .search-box input {
      width: 100%;
      padding: 12px;
      font-size: 16px;
      border: 2px solid #ddd;
      border-radius: 4px;
      font-family: 'Courier New', monospace;
    }
    .search-box input:focus { outline: none; border-color: #007bff; }
    
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 15px;
      margin: 20px 0;
    }
    .card {
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
    .card .value { font-size: 32px; font-weight: bold; color: #007bff; }
    .card .unit { font-size: 14px; color: #999; }
    
    table {
      width: 100%;
      background: white;
      border-collapse: collapse;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      margin: 20px 0;
    }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; font-size: 14px; }
    th { background: #007bff; color: white; font-weight: 600; position: sticky; top: 0; }
    th.sortable { cursor: pointer; user-select: none; position: relative; padding-right: 25px; }
    th.sortable:hover { background: #0056b3; }
    th.sortable::after { 
      content: '⇅'; 
      position: absolute; 
      right: 8px; 
      opacity: 0.5; 
      font-size: 12px; 
    }
    th.sortable.asc::after { content: '▲'; opacity: 1; }
    th.sortable.desc::after { content: '▼'; opacity: 1; }
    tr:hover { background: #f8f9fa; }
    .uuid { font-family: 'Courier New', monospace; font-size: 12px; color: #666; }
    .filename { font-family: 'Courier New', monospace; font-size: 12px; color: #333; }
    .release { font-weight: 600; color: #007bff; }
    .tags { font-size: 11px; color: #28a745; }
    .orphaned { background: #fff3cd !important; }
    .timestamp { font-size: 12px; color: #999; }
    
    .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
    .info { background: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; margin: 20px 0; }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #999; text-align: center; }
    
    .tabs {
      display: flex;
      gap: 10px;
      margin: 20px 0;
      border-bottom: 2px solid #ddd;
    }
    .tab {
      padding: 10px 20px;
      cursor: pointer;
      background: white;
      border: 2px solid #ddd;
      border-bottom: none;
      border-radius: 8px 8px 0 0;
      font-weight: 600;
      color: #666;
    }
    .tab.active {
      background: #007bff;
      color: white;
      border-color: #007bff;
    }
    .tab-content { display: none; }
    .tab-content.active { display: block; }
    
    .size-badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 11px;
      font-weight: 600;
      background: #e9ecef;
      color: #495057;
    }
    
    .release-group {
      background: white;
      margin: 15px 0;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      overflow: hidden;
    }
    .release-header {
      background: #007bff;
      color: white;
      padding: 15px 20px;
      cursor: pointer;
      display: flex;
      justify-content: space-between;
      align-items: center;
      user-select: none;
    }
    .release-header:hover {
      background: #0056b3;
    }
    .release-name {
      font-weight: 600;
      font-size: 16px;
    }
    .release-meta {
      font-size: 12px;
      opacity: 0.9;
    }
    .release-toggle {
      font-size: 20px;
      transition: transform 0.3s;
    }
    .release-group.collapsed .release-toggle {
      transform: rotate(-90deg);
    }
    .release-body {
      max-height: 2000px;
      overflow: hidden;
      transition: max-height 0.3s ease-out;
    }
    .release-group.collapsed .release-body {
      max-height: 0;
    }
    .release-body table {
      margin: 0;
      box-shadow: none;
    }
    .release-body th {
      background: #6c757d;
    }
  </style>
</head>
<body>
  <h1>🗂️ BOSH Blob UUID → Release Mapping</h1>
  <div class="subtitle">Understand which UUIDs belong to which BOSH releases</div>
  <p><strong>Bucket:</strong> s3://''' + self.bucket + '''/ | <strong>Generated:</strong> <span id="timestamp"></span></p>
  
  <div class="info">
    <strong>💡 Use Case:</strong> Search for any UUID or filename to find which buildpack releases use it. 
    Identify if orphaned blobs are from old releases that can be safely deleted.
  </div>
  
  <div class="search-box">
    <input type="text" id="search" placeholder="Search UUID, filename, or release name..." />
  </div>
  
  <div class="summary" id="summary"></div>
  
  <div class="tabs">
    <div class="tab active" onclick="switchTab('releases')">📦 By Release</div>
    <div class="tab" onclick="switchTab('uuids')">🔍 By UUID</div>
    <div class="tab" onclick="switchTab('orphaned')">🗑️ Orphaned</div>
  </div>
  
  <div id="releases-tab" class="tab-content active">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
      <h2 style="margin: 0;">Blobs Grouped by BOSH Release</h2>
      <div style="display: flex; gap: 10px; align-items: center;">
        <label style="font-size: 14px; color: #666;">Sort by:</label>
        <select id="sort-select" style="padding: 8px 12px; border: 2px solid #ddd; border-radius: 4px; font-size: 14px; cursor: pointer;">
          <option value="name">Name (A-Z)</option>
          <option value="size">Size (Largest)</option>
          <option value="blobs">Blob Count (Most)</option>
          <option value="releases">Release Count (Most)</option>
        </select>
      </div>
    </div>
    <div id="release-groups"></div>
  </div>
  
  <div id="uuids-tab" class="tab-content">
    <h2>Current UUID Mappings</h2>
    <table id="uuid-table">
      <thead>
        <tr>
          <th>UUID</th>
          <th>Filename</th>
          <th>Repository</th>
          <th>Releases</th>
          <th>Size</th>
        </tr>
      </thead>
      <tbody id="uuid-tbody"></tbody>
    </table>
  </div>
  
  <div id="orphaned-tab" class="tab-content">
    <div class="warning">
      <strong>⚠️ Warning:</strong> <span id="orphaned-count"></span> orphaned blobs detected totaling <span id="orphaned-size"></span> GB. 
      These UUIDs are in S3 but not referenced in any current blobs.yml.
    </div>
    <h2>Orphaned Blobs</h2>
    <table id="orphaned-table">
      <thead>
        <tr>
          <th>UUID</th>
          <th class="sortable" onclick="sortOrphaned('size')" id="sort-size">Size</th>
          <th class="sortable" onclick="sortOrphaned('date')" id="sort-date">Last Modified</th>
          <th>Historical Info</th>
        </tr>
      </thead>
      <tbody id="orphaned-tbody"></tbody>
    </table>
  </div>
  
  <div class="footer">
    <p>Generated by UUID Mapper Tool | Cloud Foundry Buildpacks CI</p>
  </div>
  
  <script>
    let allReleases = [];
    let allUUIDs = [];
    let allOrphaned = [];
    let allOrphanedParsed = [];
    let historicalData = {};
    let orphanedSortBy = 'size';
    let orphanedSortDir = 'desc';
    
    function switchTab(tab) {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
      event.target.classList.add('active');
      document.getElementById(tab + '-tab').classList.add('active');
    }
    
    function formatSize(bytes) {
      if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(2) + ' GB';
      if (bytes >= 1048576) return (bytes / 1048576).toFixed(2) + ' MB';
      if (bytes >= 1024) return (bytes / 1024).toFixed(2) + ' KB';
      return bytes + ' B';
    }
    
    function sortOrphaned(column) {
      if (orphanedSortBy === column) {
        orphanedSortDir = orphanedSortDir === 'asc' ? 'desc' : 'asc';
      } else {
        orphanedSortBy = column;
        orphanedSortDir = 'desc';
      }
      
      document.querySelectorAll('#orphaned-table th.sortable').forEach(th => {
        th.classList.remove('asc', 'desc');
      });
      
      const header = document.getElementById('sort-' + column);
      if (header) {
        header.classList.add(orphanedSortDir);
      }
      
      const sorted = [...allOrphanedParsed].sort((a, b) => {
        let aVal, bVal;
        if (column === 'size') {
          aVal = a.sizeBytes;
          bVal = b.sizeBytes;
        } else if (column === 'date') {
          aVal = new Date(a.date);
          bVal = new Date(b.date);
        }
        
        if (orphanedSortDir === 'asc') {
          return aVal - bVal;
        } else {
          return bVal - aVal;
        }
      });
      
      renderOrphanedData(sorted);
    }
    
    function renderOrphanedData(data) {
      const tbody = document.getElementById('orphaned-tbody');
      tbody.innerHTML = '';
      
      data.slice(0, 500).forEach(item => {
        const tr = document.createElement('tr');
        tr.className = 'orphaned';
        tr.innerHTML = `
          <td class="uuid">${item.uuid}</td>
          <td><span class="size-badge">${formatSize(item.sizeBytes)}</span></td>
          <td class="timestamp">${item.date}</td>
          <td>${item.historical ? `<div class="filename">${item.historical.filename}</div><div class="tags">Last in: ${item.historical.tags || item.historical.repo}</div>` : 'No history found'}</td>
        `;
        tbody.appendChild(tr);
      });
      
      if (data.length > 500) {
        const tr = document.createElement('tr');
        tr.innerHTML = '<td colspan="4" style="text-align: center; color: #999;">Showing first 500 results. Use search to filter.</td>';
        tbody.appendChild(tr);
      }
    }
    
    Promise.all([
      fetch('summary.json').then(r => r.json()),
      fetch('blobs_by_release.csv').then(r => r.text()),
      fetch('uuid_mapping_current.csv').then(r => r.text()),
      fetch('orphaned_blobs.csv').then(r => r.text()),
      fetch('all_blob_history.csv').then(r => r.text())
    ]).then(([summary, releaseCsv, uuidCsv, orphanedCsv, historyCsv]) => {
      
      document.getElementById('timestamp').textContent = summary.generated_at;
      
      const s = summary.summary;
      const summaryDiv = document.getElementById('summary');
      [
        { title: 'Repositories', value: s.repositories_analyzed, unit: 'repos' },
        { title: 'Total UUIDs', value: s.unique_uuids_in_history.toLocaleString(), unit: 'historical' },
        { title: 'Active UUIDs', value: s.current_active_uuids.toLocaleString(), unit: 'in use' },
        { title: 'Orphaned', value: s.orphaned_uuids.toLocaleString(), unit: 'blobs' },
        { title: 'Orphaned Size', value: s.orphaned_size_gb.toFixed(2), unit: 'GB' },
      ].forEach(card => {
        const div = document.createElement('div');
        div.className = 'card';
        div.innerHTML = `<h3>${card.title}</h3><div class="value">${card.value}</div><div class="unit">${card.unit}</div>`;
        summaryDiv.appendChild(div);
      });
      
      if (s.orphaned_uuids > 0) {
        document.getElementById('orphaned-count').textContent = s.orphaned_uuids.toLocaleString();
        document.getElementById('orphaned-size').textContent = s.orphaned_size_gb.toFixed(2);
      }
      
      historyCsv.split('\\n').slice(1).forEach(row => {
        const [uuid, filename, size, sha, repo, commit, date, author, tags] = row.split(',');
        if (uuid && !historicalData[uuid]) {
          historicalData[uuid] = { filename, repo, tags, date };
        }
      });
      
      allReleases = releaseCsv.split('\\n').slice(1).filter(r => r.trim());
      allUUIDs = uuidCsv.split('\\n').slice(1).filter(r => r.trim());
      allOrphaned = orphanedCsv.split('\\n').slice(1).filter(r => r.trim());
      
      allOrphanedParsed = allOrphaned.map(row => {
        const [uuid, size, date] = row.split(',');
        return {
          uuid,
          sizeBytes: parseInt(size) || 0,
          date,
          historical: historicalData[uuid]
        };
      }).filter(item => item.uuid);
      
      renderReleases(allReleases);
      renderUUIDs(allUUIDs);
      sortOrphaned('size');
      
      document.getElementById('search').addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase();
        renderReleases(allReleases.filter(r => r.toLowerCase().includes(query)));
        renderUUIDs(allUUIDs.filter(r => r.toLowerCase().includes(query)));
        
        const filtered = allOrphanedParsed.filter(item => 
          item.uuid.toLowerCase().includes(query) ||
          (item.historical && item.historical.filename && item.historical.filename.toLowerCase().includes(query))
        );
        renderOrphanedData(filtered);
      });
    }).catch(err => {
      document.body.innerHTML = '<div style="padding: 40px; text-align: center; color: #721c24; background: #f8d7da; margin: 20px; border-radius: 8px;"><h2>Error Loading Data</h2><p>' + err.message + '</p></div>';
    });
    
    function toggleRelease(releaseId) {
      const group = document.getElementById('group-' + releaseId);
      if (group) {
        group.classList.toggle('collapsed');
      }
    }
    
    function renderReleases(rows) {
      const container = document.getElementById('release-groups');
      container.innerHTML = '';
      
      const buildpackMap = {};
      rows.forEach(row => {
        const [release, uuid, filename, size, sha, commit, date] = row.split(',');
        if (!release) return;
        
        const buildpack = release.split('/')[0];
        
        if (!buildpackMap[buildpack]) {
          buildpackMap[buildpack] = [];
        }
        buildpackMap[buildpack].push({ release, uuid, filename, size, date });
      });
      
      const buildpacks = Object.keys(buildpackMap).sort();
      
      buildpacks.forEach((buildpack, idx) => {
        const entries = buildpackMap[buildpack];
        const totalSize = entries.reduce((sum, e) => sum + parseInt(e.size || 0), 0);
        const uniqueReleases = new Set(entries.map(e => e.release)).size;
        
        const groupDiv = document.createElement('div');
        groupDiv.className = 'release-group';
        groupDiv.id = 'group-' + idx;
        
        groupDiv.innerHTML = `
          <div class="release-header" onclick="toggleRelease(${idx})">
            <div>
              <div class="release-name">${buildpack}</div>
              <div class="release-meta">${entries.length} blobs across ${uniqueReleases} releases • ${formatSize(totalSize)}</div>
            </div>
            <div class="release-toggle">▼</div>
          </div>
          <div class="release-body">
            <table>
              <thead>
                <tr>
                  <th>Release</th>
                  <th>UUID</th>
                  <th>Filename</th>
                  <th>Size</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                ${entries.map(e => `
                  <tr>
                    <td class="release">${e.release}</td>
                    <td class="uuid">${e.uuid}</td>
                    <td class="filename">${e.filename}</td>
                    <td><span class="size-badge">${formatSize(parseInt(e.size))}</span></td>
                    <td class="timestamp">${e.date}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        `;
        
        container.appendChild(groupDiv);
      });
      
      if (buildpacks.length === 0) {
        container.innerHTML = '<div style="text-align: center; color: #999; padding: 40px; background: white; border-radius: 8px;">No results found. Try a different search.</div>';
      }
    }
    
    function renderUUIDs(rows) {
      const tbody = document.getElementById('uuid-tbody');
      tbody.innerHTML = '';
      rows.slice(0, 500).forEach(row => {
        const [uuid, filename, size, sha, repo, commit, date, author, tags] = row.split(',');
        if (!uuid) return;
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td class="uuid">${uuid}</td>
          <td class="filename">${filename}</td>
          <td>${repo}</td>
          <td class="tags">${tags || 'none'}</td>
          <td><span class="size-badge">${formatSize(parseInt(size))}</span></td>
        `;
        tbody.appendChild(tr);
      });
      if (rows.length > 500) {
        tbody.innerHTML += '<tr><td colspan="5" style="text-align: center; color: #999;">Showing first 500 results. Refine your search.</td></tr>';
      }
    }
  </script>
</body>
</html>'''
        
        output_file = self.output_dir / "report.html"
        with open(output_file, 'w') as f:
            f.write(html_template)
        
        self.log('SUCCESS', f"HTML report generated: {output_file}")
    
    def print_summary(self, summary: dict):
        """Print summary to console"""
        print("\n" + "=" * 60)
        print("         PROCESSING COMPLETE          ")
        print("=" * 60 + "\n")
        
        s = summary['summary']
        print(f"Generated: {summary['generated_at']}\n")
        print("Summary:")
        print(f"  Total blob history entries: {s['total_blob_history_entries']:,}")
        print(f"  Unique UUIDs (historical):  {s['unique_uuids_in_history']:,}")
        print(f"  Current active UUIDs:       {s['current_active_uuids']:,}")
        print(f"  UUIDs in S3 bucket:         {s['uuids_in_s3']:,}")
        print(f"  Orphaned blobs:             {s['orphaned_uuids']:,}")
        print(f"  Orphaned size:              {s['orphaned_size_gb']:.2f} GB")
        print(f"  Repositories analyzed:      {s['repositories_analyzed']}")
        print("\nOutput files:")
        print(f"  📁 {self.output_dir}/all_blob_history.csv       - Complete history")
        print(f"  📁 {self.output_dir}/uuid_mapping_current.csv   - Current mappings")
        print(f"  📁 {self.output_dir}/blobs_by_release.csv       - Blobs grouped by release/tag")
        print(f"  📁 {self.output_dir}/s3_uuid_files.csv          - S3 contents")
        print(f"  📁 {self.output_dir}/orphaned_blobs.csv         - Orphaned blobs")
        print(f"  📁 {self.output_dir}/summary.json               - JSON summary")
        print(f"  📁 {self.output_dir}/report.html                - Interactive HTML report")
        print()
    
    def start_http_server(self, port=8000, open_browser=True):
        """Start HTTP server and open browser"""
        print("\n" + "=" * 60)
        print("         STARTING WEB SERVER          ")
        print("=" * 60 + "\n")
        
        url = f"http://localhost:{port}/report.html"
        print(f"🌐 Server starting at: {url}")
        print(f"📂 Serving directory: {self.output_dir}")
        print(f"\n💡 Press Ctrl+C to stop the server\n")
        
        os.chdir(self.output_dir)
        
        class QuietHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
            def log_message(self, format, *args):
                pass
        
        if open_browser:
            threading.Timer(1.0, lambda: webbrowser.open(url)).start()
        
        try:
            with socketserver.TCPServer(("", port), QuietHTTPRequestHandler) as httpd:
                print(f"{Colors.GREEN}✓{Colors.NC} Server running. Browser should open automatically.")
                print(f"{Colors.YELLOW}⏳{Colors.NC} Keeping server alive... (Ctrl+C to stop)\n")
                httpd.serve_forever()
        except KeyboardInterrupt:
            print(f"\n\n{Colors.GREEN}✓{Colors.NC} Server stopped gracefully")
        except OSError as e:
            if "Address already in use" in str(e):
                print(f"\n{Colors.RED}✗{Colors.NC} Port {port} is already in use.")
                print(f"  Try: ./mapper.py --port {port + 1}")
                sys.exit(1)
            raise
    
    def run(self, serve=True, port=8000, open_browser=True):
        """Main execution flow"""
        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║          S3 UUID Blob Mapper - Buildpacks CI              ║")
        print("╚════════════════════════════════════════════════════════════╝\n")
        
        self.process_all_repos()
        self.save_all_history()
        self.create_current_mapping()
        self.create_release_mapping()
        self.fetch_s3_contents(use_cache=not self.refresh_s3)
        orphaned = self.identify_orphaned_blobs()
        summary = self.generate_summary(orphaned)
        self.generate_html_report()
        self.print_summary(summary)
        
        if serve:
            self.start_http_server(port=port, open_browser=open_browser)


def main():
    parser = argparse.ArgumentParser(
        description='Map BOSH blob UUIDs to filenames and start web viewer'
    )
    parser.add_argument(
        '--work-dir',
        default='./uuid-mapper-workspace',
        help='Working directory for cloned repos (default: ./uuid-mapper-workspace)'
    )
    parser.add_argument(
        '--output-dir',
        default='./output',
        help='Output directory for reports (default: ./output)'
    )
    parser.add_argument(
        '--bucket',
        default='buildpacks.cloudfoundry.org',
        help='S3 bucket name (default: buildpacks.cloudfoundry.org)'
    )
    parser.add_argument(
        '--parallel',
        type=int,
        default=4,
        help='Number of parallel workers (default: 4)'
    )
    parser.add_argument(
        '--port',
        type=int,
        default=8000,
        help='HTTP server port (default: 8000)'
    )
    parser.add_argument(
        '--no-serve',
        action='store_true',
        help='Skip starting HTTP server (just generate reports)'
    )
    parser.add_argument(
        '--no-browser',
        action='store_true',
        help='Do not open browser automatically'
    )
    parser.add_argument(
        '--refresh-s3',
        action='store_true',
        help='Force refresh S3 cache (ignore 24h cache)'
    )
    
    args = parser.parse_args()
    
    mapper = UUIDMapper(
        work_dir=args.work_dir,
        output_dir=args.output_dir,
        bucket=args.bucket,
        parallel=args.parallel,
        refresh_s3=args.refresh_s3
    )
    
    try:
        mapper.run(
            serve=not args.no_serve,
            port=args.port,
            open_browser=not args.no_browser
        )
    except KeyboardInterrupt:
        print("\n\n✓ Stopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Colors.RED}[ERROR]{Colors.NC} {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
